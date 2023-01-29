// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin-contracts/utils/Counters.sol";

import "./SlotEntry.sol";
import "../interfaces/IDaoCore.sol";

/**
 * @notice abstract contract used for Extension and DaoCore,
 * add a guard which accept only call from Adapters
 */
abstract contract Extension is SlotEntry {
    /**
     * @notice Check on DaoCore if the msg.sender is
     * registered in the Dao at the right slot
     */
    modifier onlyAdapter(bytes4 slot_) {
        require(
            IDaoCore(_core).getSlotContractAddr(slot_) == msg.sender,
            "Cores: not the right adapter"
        );
        _;
    }

    /**
     * @notice Specific check for the slot Managing to keep the
     * legacy contract functional in case the new is not working
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

    constructor(address core, bytes4 slot) SlotEntry(core, slot, true) {}

    // add flags?: desactived, new/next states, migrated
}
