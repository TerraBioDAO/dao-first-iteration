// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";

import { MEMBER, ADMIN, ENTRY_MANAGER, MEMBERSHIP_MANAGER, CORE } from "src/helpers/Roles.sol";

import { Extension } from "../abstracts/Extension.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";
import { Constants } from "../helpers/Constants.sol";
import { Slot } from "../helpers/Slot.sol";
import { ISlotEntry } from "../interfaces/ISlotEntry.sol";

contract DaoCore is AccessControl, Extension, IDaoCore, Constants {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice track of Extensions and Adapters
    mapping(bytes4 => Entry) private _entries;

    /// @notice address of the legacy managing adapter
    address private _legacyManaging;

    // --- v0.2 ---
    EnumerableSet.AddressSet private _membersList;
    EnumerableSet.AddressSet private _entriesList;
    EnumerableSet.Bytes32Set private _rolesList;

    /**
     * @notice `admin` become grant the role of MANAGING and ONBOARDING to add
     * new member in the DAO and new Entries
     */
    constructor(address admin) Extension(address(this), Slot.CORE) {
        _setRoleAdmin(ENTRY_MANAGER, CORE);
        _setRoleAdmin(MEMBERSHIP_MANAGER, CORE);
        _setRoleAdmin(MEMBER, MEMBERSHIP_MANAGER);
        _setRoleAdmin(ADMIN, MEMBERSHIP_MANAGER);

        _rolesList.add(CORE);
        _rolesList.add(MEMBER);
        _rolesList.add(ADMIN);
        _rolesList.add(ENTRY_MANAGER);
        _rolesList.add(MEMBERSHIP_MANAGER);

        _membersList.add(admin);
        _grantRole(MEMBER, admin);
        _grantRole(ADMIN, admin);
        _grantRole(ENTRY_MANAGER, admin);
        _grantRole(MEMBERSHIP_MANAGER, admin);
    }

    /*//////////////////////////////////////////////////////////
                      PUBLIC FONCTIONS (OVERRIDE)
    //////////////////////////////////////////////////////////*/
    function grantRole(bytes32 role, address account) public override {
        require(_rolesList.contains(role), "Core: inexistant role");
        super.grantRole(role, account);
        if (role == MEMBER) {
            _membersList.add(account);
        }
    }

    function revokeRole(bytes32 role, address account) public override {
        require(_rolesList.contains(role), "Core: inexistant role");
        super.revokeRole(role, account);
        if (role == MEMBER) {
            _membersList.remove(account);
        }
    }

    function renounceRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {}

    /*//////////////////////////////////////////////////////////
                      PUBLIC FONCTIONS (BATCH)
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Change members status by batch
     *
     * TODO check the limit max of list length and check
     * gas saving
     */
    function batchChangeMembersStatus(
        address[] memory accounts,
        bytes32[] memory roles,
        bool[] memory values
    ) external onlyRole(MEMBERSHIP_MANAGER) {
        require(
            accounts.length == roles.length && accounts.length == values.length,
            "Core: list mismatch"
        );

        for (uint256 i; i < accounts.length; ) {
            if (values[i]) {
                grantRole(roles[i], accounts[i]);
            } else {
                revokeRole(roles[i], accounts[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Change slot entries by batch
     *
     * TODO check the limit max of list length and check
     * gas saving
     */
    function batchChangeEntriesStatus(
        address[] memory entriesAddr,
        bytes32[] memory roles,
        bool[] memory values
    ) external onlyRole(ENTRY_MANAGER) {
        require(
            entriesAddr.length == roles.length && entriesAddr.length == values.length,
            "Core: list mismatch"
        );
        for (uint256 i; i < entriesAddr.length; ) {
            if (values[i]) {
                // add check
                _entriesList.add(entriesAddr[i]);
                grantRole(roles[i], entriesAddr[i]);
            } else {
                _entriesList.remove(entriesAddr[i]);
                revokeRole(roles[i], entriesAddr[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////
                        PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/
    function addNewEntry(address entry, bytes32 role) external onlyRole(ENTRY_MANAGER) {
        //
    }

    function createSubRole(bytes32 subRole, bytes32 role) external onlyRole(role) {
        require(getRoleAdmin(role) == CORE, "Core: Only top roles");
        _rolesList.add(subRole);
        _setRoleAdmin(subRole, role);
    }

    function removeSubRole(bytes32 subRole, bytes32 role) external onlyRole(role) {
        require(getRoleAdmin(subRole) == role, "Core: role isn't subrole");
        _rolesList.remove(subRole);
    }

    /*//////////////////////////////////////////////////////////
                                GETTERS 
    //////////////////////////////////////////////////////////*/
    function numberOfMembers() external view returns (uint256) {
        return _membersList.length();
    }

    function membersList() external view returns (address[] memory) {
        return _membersList.values();
    }

    function numberOfEntries() external view returns (uint256) {
        return _entriesList.length();
    }

    function entriesList() external view returns (address[] memory) {
        return _entriesList.values();
    }

    function numberOfRoles() external view returns (uint256) {
        return _rolesList.length();
    }

    function rolesList() external view returns (bytes32[] memory) {
        return _rolesList.values();
    }

    function roleExist(bytes32 role) external view returns (bool) {
        return _rolesList.contains(role);
    }

    /* //////////////////////////
                GETTERS
    ////////////////////////// */
    function isSlotActive(bytes4 slot) external view returns (bool) {
        return _entries[slot].slot != Slot.EMPTY;
    }

    function isSlotExtension(bytes4 slot) external view returns (bool) {
        return _entries[slot].isExtension;
    }

    /**
     * TODO remove from struct and check gas opt has called often
     */
    function getSlotContractAddr(bytes4 slot) external view returns (address) {
        return _entries[slot].contractAddr;
    }

    function legacyManaging() external view returns (address) {
        return _legacyManaging;
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */

    /**
     * @notice This function check the validity of the new contract
     * by trying to call `ISlotEntry.slotId()` and check if a `bytes4`
     * is returned
     */
    function _getSlotFromCandidate(address contractAddr) private view returns (bytes4) {
        // low level call "try/catch" => https://github.com/dragonfly-xyz/useful-solidity-patterns/tree/main/patterns/error-handling#low-level-calls
        (, bytes memory slotIdData) = address(contractAddr).staticcall(
            // Encode the call data (function on someContract to call + arguments)
            abi.encodeCall(ISlotEntry.slotId, ())
        );
        require(slotIdData.length == 32, "Core: inexistant slotId() impl");
        return bytes4(slotIdData);
    }
}
