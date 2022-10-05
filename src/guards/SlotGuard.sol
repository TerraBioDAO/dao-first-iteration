// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "./ISlotEntry.sol";

abstract contract SlotGuard is ISlotEntry {
    address internal immutable _core;
    bytes4 public immutable override slotId;
    bool public immutable override isExtension;

    modifier onlyCore() {
        require(msg.sender == _core, "SlotGuard: not the core");
        _;
    }

    modifier onlyMember() {
        require(
            IDaoCore(_core).hasRole(msg.sender, Slot.USER_EXISTS),
            "SlotGuard: not a member"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            IDaoCore(_core).hasRole(msg.sender, Slot.USER_ADMIN),
            "SlotGuard: not an admin"
        );
        _;
    }

    constructor(address core, bytes4 slot) {
        require(slot != Slot.EMPTY, "SlotGuard: empty slot");
        require(core != address(0), "SlotGuard: zero core address");
        _core = core;
        slotId = slot;
        isExtension = false;
    }
}
