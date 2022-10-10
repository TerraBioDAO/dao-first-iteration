// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "./IDaoCore.sol";
import "../guards/CoreGuard.sol";

/**
 * @notice Main contract, keep states of the DAO
 */

contract DaoCore is IDaoCore, CoreGuard {
    /// @notice The map to track all members of the DAO with their roles or credits
    mapping(address => mapping(bytes4 => bool)) public members;

    /// @notice counter for existing members
    uint256 public override membersCount;

    /// @notice list of existing roles in the DAO
    bytes4[] public roles;

    /// @notice keeps track of Extensions and Adapters
    mapping(bytes4 => Entry) public entries;

    constructor(address admin, address managing)
        CoreGuard(address(this), Slot.CORE)
    {
        _changeMemberStatus(admin, Slot.USER_EXISTS, true);
        _changeMemberStatus(admin, Slot.USER_ADMIN, true);
        _addSlotEntry(Slot.MANAGING, managing, false);
    }

    function changeSlotEntry(bytes4 slot, address contractAddr)
        external
        onlyAdapter(Slot.MANAGING)
    {
        require(slot != Slot.EMPTY, "Core: empty slot");
        Entry memory e = entries[slot];

        if (contractAddr == address(0)) {
            _removeSlotEntry(slot);
        } else {
            require(
                ISlotEntry(contractAddr).slotId() == slot,
                "Core: slot & address not match"
            );

            if (e.slot == Slot.EMPTY) {
                e.isExtension = ISlotEntry(contractAddr).isExtension();
                _addSlotEntry(slot, contractAddr, e.isExtension);
            } else {
                // replace => ext is ext!
                bool isExt = ISlotEntry(contractAddr).isExtension();
                require(e.isExtension == isExt, "Core: wrong entry setup");
                e.isExtension = isExt; // for event
                _addSlotEntry(slot, contractAddr, isExt);
            }
        }

        emit SlotEntryChanged(
            slot,
            e.isExtension,
            e.contractAddr,
            contractAddr
        );
    }

    function changeMemberStatus(
        address account,
        bytes4 role,
        bool value
    ) external onlyAdapter(Slot.ONBOARDING) {
        require(account != address(0), "Core: zero address used");

        //
        _changeMemberStatus(account, role, value);
    }

    // GETTERS
    function hasRole(address account, bytes4 role)
        external
        view
        returns (bool)
    {
        return members[account][role];
    }

    function isSlotActive(bytes4 slot) external view returns (bool) {
        return entries[slot].slot != Slot.EMPTY;
    }

    function isSlotExtension(bytes4 slot) external view returns (bool) {
        return entries[slot].isExtension;
    }

    function getSlotContractAddr(bytes4 slot) external view returns (address) {
        return entries[slot].contractAddr;
    }

    // INTERNAL FUNCTIONS
    function _newMember(address account, bool isAdmin) internal {
        require(!members[account][Slot.USER_EXISTS], "Core: already a member");
        unchecked {
            ++membersCount;
        }
        members[account][Slot.USER_EXISTS] = true;

        if (isAdmin) {
            members[account][Slot.USER_ADMIN] = true;
        }
    }

    function _revokeMember(address account) internal {
        bytes4[] memory rolesList = roles;

        for (uint256 i; i < rolesList.length; ) {
            delete members[account][rolesList[i]];
            unchecked {
                ++i;
            }
        }

        unchecked {
            --membersCount;
        }
    }

    function _changeMemberStatus(
        address account,
        bytes4 role,
        bool value
    ) internal {
        require(account != address(0), "Core: zero address used");
        require(members[account][role] != value, "Core: role not changing");

        members[account][role] = value;
        emit MemberStatusChanged(account, role, value);
    }

    function _addSlotEntry(
        bytes4 slot,
        address newContractAddr,
        bool isExt
    ) internal {
        entries[slot] = Entry(slot, isExt, newContractAddr);
    }

    function _removeSlotEntry(bytes4 slot) internal {
        delete entries[slot];
    }
}
