// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Counters } from "openzeppelin-contracts/utils/Counters.sol";

import { SlotEntry, Slot } from "./SlotEntry.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";

/**
 * @title Abstract contract to implement restriction access of Extensions
 * @dev Only implement modifiers, not states is implemented
 */
abstract contract Extension is SlotEntry {
    /**
     * @dev Allow only a specific adapter
     * @param slot_ slotID of the adapter
     */
    modifier onlyAdapter(bytes4 slot_) {
        require(
            IDaoCore(_core).getSlotContractAddr(slot_) == msg.sender,
            "Cores: not the right adapter"
        );
        _;
    }

    /**
     * @dev Allow only the managing adapter, and its legacy one
     */
    modifier onlyManaging() {
        address expectedAddr = IDaoCore(_core).getSlotContractAddr(Slot.MANAGING);
        address legacyAddr = IDaoCore(_core).legacyManaging();
        require(
            msg.sender == expectedAddr || msg.sender == legacyAddr,
            "Cores: not Managing contract"
        );
        _;
    }

    /**
     * @param core address of DaoCore
     * @param slot slotID of the extension
     */
    constructor(address core, bytes4 slot) SlotEntry(core, slot, true) {}
}
