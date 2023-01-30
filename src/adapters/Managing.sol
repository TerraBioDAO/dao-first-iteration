// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { ProposerAdapter, Adapter, Slot } from "../abstracts/ProposerAdapter.sol";
import { IAgora } from "../interfaces/IAgora.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";

/**
 * @notice contract interacting with the Core to add or remove Entry
 * to the DAO.
 * CAUTION: this contract must always have the possibility to add and remove Slots
 * in the DAO, otherwise the DAO can be blocked
 */

contract Managing is ProposerAdapter {
    struct EntryProposal {
        bytes4 slot;
        bool isExtension;
        address contractAddr;
    }

    mapping(bytes28 => EntryProposal) private _proposals;

    constructor(address core) Adapter(core, Slot.MANAGING) {}

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
    /**
     * @notice allow member to propose a new entry to the DAO
     * Propositions need an approval from the admin
     */
    function proposeEntry(
        bytes4 entrySlot,
        bool isExt,
        address contractAddr,
        bytes4 voteParamId,
        uint32 minStartTime
    ) external onlyMember {
        // checking the proposed contract is done in Agora

        // construct the proposal
        EntryProposal memory entryProposal_ = EntryProposal(entrySlot, isExt, contractAddr);
        bytes28 proposalId = bytes28(keccak256(abi.encode(entryProposal_)));

        // store proposal data and check adapter state
        _newProposal();
        _proposals[proposalId] = entryProposal_;

        // send to Agora
        IAgora(_slotAddress(Slot.AGORA)).submitProposal(
            entrySlot,
            proposalId,
            false,
            voteParamId,
            minStartTime,
            msg.sender
        );
    }

    /**
     * @notice change a slot entry without vote, useful for
     * quick add of Slot
     *
     * NOTE consider disable this function when the DAO reach a certain
     * size to let only member decide as admin can abuse of it. But can
     * be useful in ermergency situation
     *
     * NOTE a commitment logic can be implemented to let another admin check
     * the new contract
     */
    function manageSlotEntry(bytes4 entrySlot, address contractAddr) external onlyAdmin {
        IDaoCore(_core).changeSlotEntry(entrySlot, contractAddr);
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    function _executeProposal(bytes32 proposalId) internal override {
        EntryProposal memory entryProposal_ = _proposals[_readProposalId(proposalId)];
        IDaoCore(_core).changeSlotEntry(entryProposal_.slot, entryProposal_.contractAddr);
    }
}
