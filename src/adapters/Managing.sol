// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/ProposerAdapter.sol";
import "../interfaces/IAgora.sol";
import "../interfaces/IDaoCore.sol";

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

        // send to Agora
        IAgora(_slotAddress(Slot.AGORA)).submitProposal(
            entrySlot,
            proposalId,
            false,
            voteParamId,
            minStartTime,
            msg.sender
        );
        _newProposal();
    }

    function finalizeProposal(bytes32 proposalId) external override onlyMember {
        (IAgora.VoteResult result, IAgora agora) = _checkProposalResult(proposalId);

        if (uint256(result) == 0) {
            _executeProposal(proposalId);
        }

        agora.finalizeProposal(proposalId, msg.sender, result);
    }

    /**
     * @notice change a slot entry without vote
     * should add a VETO by others admin?
     * add commitment logic?
     */
    function manageSlotEntry(bytes4 entrySlot, address contractAddr) external onlyAdmin {
        IDaoCore(_core).changeSlotEntry(entrySlot, contractAddr);
    }

    function _executeProposal(bytes32 proposalId) internal override {
        super._executeProposal(proposalId);

        EntryProposal memory entryProposal_ = _proposals[bytes28(proposalId << 32)];
        IDaoCore(_core).changeSlotEntry(entryProposal_.slot, entryProposal_.contractAddr);
    }
}
