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
    modifier onlyAdapter(bytes4 slot_) {
        require(
            IDaoCore(_core).getSlotContractAddr(slot_) == msg.sender,
            "Cores: not the right adapter"
        );
        _;
    }

    constructor(address core, bytes4 slot) SlotEntry(core, slot, true) {}
}
