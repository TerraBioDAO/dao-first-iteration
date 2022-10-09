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

    /// @notice keeps track of Extensions and Adapters
    mapping(bytes4 => Entry) public entries;

    constructor(address admin, address managingContractAddr)
    CoreGuard(address(this), Slot.CORE)
    {
        _changeMemberStatus(admin, Slot.USER_EXISTS, true);
        _changeMemberStatus(admin, Slot.USER_ADMIN, true);
        address managingAddr = managingContractAddr == address(0)
        ? admin
        : managingContractAddr;
        _changeSlotEntry(Slot.MANAGING, managingAddr, false);
    }

    function changeSlotEntry(bytes4 slot, address contractAddr, bool isExt)
    external
    onlyAdapter(Slot.MANAGING)
    {
        _changeSlotEntry(slot, contractAddr, isExt);
    }

    function changeMemberStatus(address account, bytes4 role, bool value)
    external
    onlyAdapter(Slot.ONBOARDING)
    {
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

    function getSlotContractAddr(bytes4 slot)
    external
    view
    returns (address)
    {
        return entries[slot].contractAddr;
    }

    // INTERNAL FUNCTIONS
    function _changeMemberStatus(address account, bytes4 role, bool value)
    internal
    {
        require(account != address(0), "Core: zero address used");
        require(members[account][role] != value, "Core: role not changing");

        if (role == Slot.USER_EXISTS) {
        unchecked {
            value ? ++membersCount : --membersCount;
        }
        }

        members[account][role] = value;
        emit MemberStatusChanged(account, role, value);
    }

    function _changeSlotEntry(
        bytes4 slot,
        address newContractAddr,
        bool isExt
    ) internal {
        require(slot != Slot.EMPTY, "Core: empty slot");
        Entry storage e = entries[slot];

        if (newContractAddr != address(0)) {
            // add entry
            //TODO faire un cast avec l'interface ISlotEntry ?? quel changement fait on, adress et ou type ?
            require(e.contractAddr == address(0) || e.isExtension == isExt, "Core: wrong entry setup");
            e.slot = slot;
            e.contractAddr = newContractAddr;
            e.isExtension = isExt;
        } else {
            // remove entry
            delete entries[slot];
        }

        emit SlotEntryChanged(
            slot, isExt, e.contractAddr, newContractAddr
        );
    }
}
