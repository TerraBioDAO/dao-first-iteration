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

    function submitProposal(
        bytes4 entrySlot,
        bool isExt,
        address contractAddr,
        address votingContract
    ) external onlyAdmin {
        // check the contract input
        ISlotEntry entry = ISlotEntry(contractAddr);
        require(
            entry.slotId() == entrySlot && entry.isExtension() == isExt,
            "Managing: wrong entry setup"
        );

        // check votingContract

        Proposal memory proposal = Proposal(entrySlot, isExt, contractAddr, votingContract);
        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        // store in the core
        // IDaoCore(_core).submitProposal(
        //     bytes32(bytes.concat(slotId, proposalId)),
        //     msg.sender,
        //     votingContract
        // );
    }

    function processProposal(bytes32 proposalId) external onlyCore {
        Proposal memory p = proposals[bytes28(proposalId << 32)];
        IDaoCore(_core).changeSlotEntry(p.slot, p.contractAddr);
        delete proposals[bytes28(proposalId << 32)];
    }

    /**
     * @notice change a slot entry without vote
     * Should add a VETO by others admin
     */
    function manageSlotEntry(
        bytes4 entrySlot,
        bool isExt,
        address contractAddr
    ) external onlyAdmin {
        IDaoCore(_core).changeSlotEntry(entrySlot, contractAddr);
    }
}
