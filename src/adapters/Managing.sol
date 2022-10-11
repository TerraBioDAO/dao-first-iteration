// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "../guards/SlotGuard.sol";

/**
 * @notice MOST important contract in the DAO, as it allow to add/remove adapters & extensions
 * if this contract deprecaced this fonction the DAO cannot evolve anymore
 */

contract Managing is SlotGuard {
    struct Proposal {
        bytes4 slot;
        bool isExtension;
        address contractAddr;
        address votingContract;
    }

    mapping(bytes28 => Proposal) public proposals;

    constructor(address core) SlotGuard(core, Slot.MANAGING) {}

    /**
     * @notice change a slot entry without vote
     * Should add a VETO by others admin
     */
    function manageSlotEntry(bytes4 entrySlot, address contractAddr) external onlyAdmin {
        IDaoCore(_core).changeSlotEntry(entrySlot, contractAddr);
    }

    // Add proposals logics once Agora.sol is ready
}
