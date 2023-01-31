// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { Extension } from "./abstracts/Extension.sol";
import { IDaoCore } from "./interfaces/IDaoCore.sol";
import { Constants } from "./helpers/Constants.sol";
import { Slot } from "./helpers/Slot.sol";
import { ISlotEntry } from "./interfaces/ISlotEntry.sol";

/**
 * @title Core contract to manage roles and dependencies of the DAO
 * @notice End users do not interact directly with this contract (read-only)
 *
 * @dev Only `adapters` interacting with this contract execpt during
 * the deployment, where an `admin` is in charge to register initial
 * members and adapters/extensions (entries).
 */
contract DaoCore is Extension, IDaoCore, Constants {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @dev track all members of the DAO with their roles
    mapping(address => mapping(bytes32 => bool)) private _members;

    /// @notice counter of existing members
    uint256 public override membersCount;

    /// @dev list of existing roles in the DAO
    EnumerableSet.Bytes32Set private _roles;

    /// @dev track of Extensions and Adapters
    mapping(bytes4 => Entry) private _entries;

    /// @dev address of the legacy managing adapter
    address private _legacyManaging;

    /**
     * @dev `admin` acting as the MANAGING and ONBOARDING adapters during the
     * deployment to facilitate registration of initial members and entries. Then
     * the `admin` should renouce this role by calling {changeSlotEntry}.
     *@param admin address in charge of the deployment step.
     */
    constructor(address admin) Extension(address(this), Slot.CORE) {
        _changeMemberStatus(admin, ROLE_MEMBER, true);
        _changeMemberStatus(admin, ROLE_ADMIN, true);

        _entries[Slot.MANAGING] = Entry(Slot.MANAGING, false, admin);
        _entries[Slot.ONBOARDING] = Entry(Slot.ONBOARDING, false, admin);

        // push roles
        _roles.add(ROLE_MEMBER);
        _roles.add(ROLE_ADMIN);
    }

    /*//////////////////////////////////////////////////////////
                            PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Change members status by batch
     *
     * @param accounts list of address to change status
     * @param roles list of roles to grant or revoke
     * @param values list of flag for granting or revoking roles
     */
    function batchChangeMembersStatus(
        address[] memory accounts,
        bytes32[] memory roles,
        bool[] memory values
    ) external onlyAdapter(Slot.ONBOARDING) {
        require(
            accounts.length == roles.length && accounts.length == values.length,
            "Core: list mismatch"
        );

        for (uint256 i; i < accounts.length; ) {
            _changeMemberStatus(accounts[i], roles[i], values[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Change slot entries by batch
     *
     * @param slots list of slots to change
     * @param contractsAddr address of contracts assigned to a slot
     */
    function batchChangeSlotEntries(bytes4[] memory slots, address[] memory contractsAddr)
        external
        onlyManaging
    {
        require(slots.length == contractsAddr.length, "Core: list mismatch");
        for (uint256 i; i < slots.length; ) {
            _changeSlotEntry(slots[i], contractsAddr[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Change one member status
     *
     * @param account address to change status
     * @param role role to grant or revoke
     * @param value flag for granting or revoking a role
     */
    function changeMemberStatus(
        address account,
        bytes32 role,
        bool value
    ) external onlyAdapter(Slot.ONBOARDING) {
        _changeMemberStatus(account, role, value);
    }

    /**
     * @notice Change one slot entry
     *
     * @param slot slot to change
     * @param contractAddr address of contracts assigned to the slot
     */
    function changeSlotEntry(bytes4 slot, address contractAddr) external onlyManaging {
        _changeSlotEntry(slot, contractAddr);
    }

    /**
     * @notice Register a new role in the DAO
     *
     * @param role role to register
     */
    function addNewRole(bytes32 role) external onlyAdapter(Slot.ONBOARDING) {
        require(!_roles.contains(role), "Core: role already exist");
        _roles.add(role);
    }

    /**
     * @notice Remove a role from the DAO
     *
     * @param role role to remove
     */
    function removeRole(bytes32 role) external onlyAdapter(Slot.ONBOARDING) {
        require(_roles.contains(role), "Core: inexistant role");
        _roles.remove(role);
    }

    /*//////////////////////////////////////////////////////////
                                GETTER 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a role is attributed to an address
     * @param account address to check
     * @param role attributed role
     * @return true if the account has the role
     */
    function hasRole(address account, bytes32 role) external view returns (bool) {
        return _members[account][role];
    }

    /**
     * @notice Check if a role is registered in the DAO
     * @param role role to check
     * @return true if the role exist
     */
    function rolesActive(bytes32 role) external view returns (bool) {
        return _roles.contains(role);
    }

    /**
     * @return number of roles registered
     */
    function getNumberOfRoles() external view returns (uint256) {
        return _roles.length();
    }

    /**
     * @notice Get the role at a specific index
     * @param index index to check
     * @return bytes32 of the role
     */
    function getRolesByIndex(uint256 index) external view returns (bytes32) {
        return _roles.at(index);
    }

    /**
     * @notice Check is a slot is registered in the DAO
     * @param slot slot to check
     * @return true if registered
     */
    function isSlotActive(bytes4 slot) external view returns (bool) {
        return _entries[slot].slot != Slot.EMPTY;
    }

    /**
     * @notice Check is a slot is an extension
     * @param slot slot to check
     * @return true if the slot is an extension
     */
    function isSlotExtension(bytes4 slot) external view returns (bool) {
        return _entries[slot].isExtension;
    }

    /**
     * @notice Get the address associated with a slot
     * @param slot slot to check
     * @return address of the contract
     */
    function getSlotContractAddr(bytes4 slot) external view returns (address) {
        return _entries[slot].contractAddr;
    }

    /**
     * @dev After the deployment the legacy MANAGING is the deployment `admin`
     * @return address of the previous MANAGING contract
     */
    function legacyManaging() external view returns (address) {
        return _legacyManaging;
    }

    /*//////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @dev Increment or decrement the counter of members if the
     * role is {ROLE_MEMBER}.
     * Emit {MemberStatusChanged}
     *
     * @param account address to change status
     * @param role role to grant or revoke
     * @param value flag for granting or revoking a role
     */
    function _changeMemberStatus(
        address account,
        bytes32 role,
        bool value
    ) private {
        require(account != address(0), "Core: zero address used");
        require(_members[account][role] != value, "Core: role not affected");
        if (role == ROLE_MEMBER) {
            if (value) {
                unchecked {
                    ++membersCount;
                }
            } else {
                _revokeMember(account);
            }
        }

        _members[account][role] = value;
        emit MemberStatusChanged(account, role, value);
    }

    /**
     * @dev Remove all registered roles for this address, and
     * decrement the counter of member. This function is used
     * when an user quit the DAO.
     *
     * @param account address to revoke
     */
    function _revokeMember(address account) internal {
        for (uint256 i; i < _roles.length(); ) {
            delete _members[account][_roles.at(i)];
            unchecked {
                ++i;
            }
        }
        unchecked {
            --membersCount;
        }
    }

    /**
     * @dev Register, replace or remove a slot entry. The function
     * check if the contract is well implemented see {_getSlotFromCandidate}.
     * Special case when the MANAGING slot is replaced, the {_legacyManaging}
     * is updated.
     *
     * NOTE At deployment, after the deployer/admin replace Managing
     * he becomes the `legacyManaging`, assuming this address cannot be
     * corrupt or cheat.
     * NOTE The MANAGING slot cannot be removed.
     *
     * @param slot slot to change
     * @param contractAddr address of contracts assigned to the slot
     */
    function _changeSlotEntry(bytes4 slot, address contractAddr) private {
        require(slot != Slot.EMPTY, "Core: empty slot");
        Entry memory entry = _entries[slot];

        // remove contract
        if (contractAddr == address(0)) {
            require(slot != Slot.MANAGING, "Core: cannot remove Managing");
            emit SlotEntryChanged(slot, entry.isExtension, entry.contractAddr, address(0));
            delete _entries[slot];
            return;
        }

        // check if contract implement `slotId`
        require(slot == _getSlotFromCandidate(contractAddr), "Core: slot & address not match");

        // check if replacement is valid
        bool candidateSlotType = ISlotEntry(contractAddr).isExtension();
        if (entry.slot != Slot.EMPTY) {
            require(entry.isExtension == candidateSlotType, "Core: slot type mismatch");
            if (slot == Slot.MANAGING) _legacyManaging = entry.contractAddr;
        }

        // store new slot
        _entries[slot] = Entry(slot, candidateSlotType, contractAddr);
        emit SlotEntryChanged(slot, candidateSlotType, entry.contractAddr, contractAddr);
    }

    /**
     * @dev Called whena new contract is associated with a slot,
     * the function check is {slotId()} return a bytes4, corresponding
     * to the slot of the contract.
     *
     * @param contractAddr address to check
     * @return slotId (bytes4)
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
