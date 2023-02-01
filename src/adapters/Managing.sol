// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { ProposerAdapter, Adapter, Slot } from "../abstracts/ProposerAdapter.sol";
import { IAgora } from "../interfaces/IAgora.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";

/**
 * @title Contract in charge of adding, replacing and removing entries to the
 * DaoCore.
 * @notice Users can submit proposals for managing entries in DaoCore
 *
 * TODO Implementation for batching entry managment
 *
 * @dev Admins can manage entries without requesting a proposal submission
 */
contract Managing is ProposerAdapter {
    struct EntryProposal {
        bytes4 slot;
        bool isExtension;
        address contractAddr;
    }

    /// @dev track proposals by their hash
    mapping(bytes28 => EntryProposal) private _proposals;

    /// @param core address of DaoCore
    constructor(address core) Adapter(core, Slot.MANAGING) {}

    /*//////////////////////////////////////////////////////////
                            PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Allow members to propose an entry managment, address(0) is
     * chosen to removing entry. Proposal need admin approval.
     *
     * @param entrySlot slotID to manage
     * @param isExt flag to distinct adapters and extensions
     * @param contractAddr address of the new entry (zero in case in removal)
     * @param voteParamId vote parameter for this proposal
     * @param minStartTime timestamp when the voting peiod should start (zero for now)
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
     * @notice Allow admin to manage entries without submitting a
     * proposal.
     * @dev Checks by others admins should be implemented here
     *
     * @param entrySlot slotID to manage
     * @param contractAddr address of the new entry (zero in case in removal)
     */
    function manageSlotEntry(bytes4 entrySlot, address contractAddr) external onlyAdmin {
        IDaoCore(_core).changeSlotEntry(entrySlot, contractAddr);
    }

    /*//////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////
                        INTERNAL FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @dev Implementation of {_executeProposal}
     *
     * @param proposalId transaction request to execute
     */
    function _executeProposal(bytes32 proposalId) internal override {
        EntryProposal memory entryProposal_ = _proposals[_readProposalId(proposalId)];
        IDaoCore(_core).changeSlotEntry(entryProposal_.slot, entryProposal_.contractAddr);
    }
}
