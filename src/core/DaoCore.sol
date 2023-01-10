// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import "../abstracts/Extension.sol";
import "../interfaces/IDaoCore.sol";
import "../helpers/Constants.sol";

contract DaoCore is Extension, IDaoCore, Constants {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice track all members of the DAO with their roles
    mapping(address => mapping(bytes32 => bool)) private _members;

    /// @notice counter of existing members
    uint256 public override membersCount;

    /// @notice list of existing roles in the DAO
    EnumerableSet.Bytes32Set private _roles;

    /// @notice track of Extensions and Adapters
    mapping(bytes4 => Entry) private _entries;

    /// @notice address of the legacy managing adapter
    address private _legacyManaging;

    /**
     * @notice `admin` become grant the role of MANAGING and ONBOARDING to add
     * new member in the DAO and new Entries
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

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */

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
     * TODO check the limit max of list length and check
     * gas saving
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
     */
    function changeMemberStatus(
        address account,
        bytes32 role,
        bool value
    ) external onlyAdapter(Slot.ONBOARDING) {
        _changeMemberStatus(account, role, value);
    }

    /**
     * @notice change slot entry
     */
    function changeSlotEntry(bytes4 slot, address contractAddr) external onlyManaging {
        _changeSlotEntry(slot, contractAddr);
    }

    function addNewRole(bytes32 role) external onlyAdapter(Slot.ONBOARDING) {
        require(!_roles.contains(role), "Core: role already exist");
        _roles.add(role);
    }

    function removeRole(bytes32 role) external onlyAdapter(Slot.ONBOARDING) {
        require(_roles.contains(role), "Core: inexistant role");
        _roles.remove(role);
    }

    /* //////////////////////////
                GETTERS
    ////////////////////////// */
    function hasRole(address account, bytes32 role) external view returns (bool) {
        return _members[account][role];
    }

    function rolesActive(bytes32 role) external view returns (bool) {
        return _roles.contains(role);
    }

    function getNumberOfRoles() external view returns (uint256) {
        return _roles.length();
    }

    function getRolesByIndex(uint256 index) external view returns (bytes32) {
        return _roles.at(index);
    }

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
     * @notice internal function to change role account
     * roles existance is not checked
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
     * @notice delete all registered roles in the DAO
     * and decrease the members counter
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
     * @notice add, replace or remove slot entry
     *
     * NOTE At deployment, after the deployer/admin replace Managing
     * he becomes the `legacyManaging`, assuming this address cannot be
     * corrupt or cheat
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
