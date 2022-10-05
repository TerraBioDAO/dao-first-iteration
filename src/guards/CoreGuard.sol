// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "./ISlotEntry.sol";

abstract contract CoreGuard is ISlotEntry {
    address internal immutable _core;
    bytes4 public immutable override slotId;
    bool public immutable override isExtension;

    modifier onlyAdapter(bytes4 slot_) {
        require(
            IDaoCore(_core).slotContract(slot_) == msg.sender,
            "CoreGuard: not the right adapter"
        );
        _;
    }

    constructor(address core, bytes4 slot) {
        require(core != address(0), "CoreGuard: zero address");
        require(slot != Slot.EMPTY, "CoreGuard: empty slot");
        _core = core;
        slotId = slot;
        isExtension = true;
    }
}
