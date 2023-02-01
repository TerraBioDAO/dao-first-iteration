// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Slot } from "../helpers/Slot.sol";
import { ISlotEntry } from "../interfaces/ISlotEntry.sol";

/**
 * @title Abstract contract to add general informations into the bytecode
 * @dev Every componants of the DAO implement this code
 */
abstract contract SlotEntry is ISlotEntry {
    /// @dev address of DaoCore
    address internal immutable _core;

    /// @return slotId of this contract
    bytes4 public immutable override slotId;

    /// @return true is this contract is an extension
    bool public immutable override isExtension;

    /**
     * @param core address of DaoCore
     * @param slot slotID of this contract
     * @param isExt flag for adapters or extensions
     */
    constructor(
        address core,
        bytes4 slot,
        bool isExt
    ) {
        require(core != address(0), "SlotEntry: zero address");
        require(slot != Slot.EMPTY, "SlotEntry: empty slot");
        _core = core;
        slotId = slot;
        isExtension = isExt;
    }
}
