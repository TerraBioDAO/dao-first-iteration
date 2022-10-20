// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../interfaces/ISlotEntry.sol";

abstract contract SlotEntry is ISlotEntry {
    address internal immutable _core;
    bytes4 public immutable override slotId;
    bool public immutable override isExtension;

    constructor(
        address core,
        bytes4 slot,
        bool isExt
    ) {
        require(core != address(0), "CoreGuard: zero address");
        require(slot != Slot.EMPTY, "CoreGuard: empty slot");
        _core = core;
        slotId = slot;
        isExtension = isExt;
    }
}
