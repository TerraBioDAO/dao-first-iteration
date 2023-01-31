// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Extension, Slot } from "../abstracts/Extension.sol";
import { Constants } from "../helpers/Constants.sol";
import { IAgora } from "../interfaces/IAgora.sol";
import { IProposerAdapter } from "../interfaces/IProposerAdapter.sol";

/**
 * @title Extension contract for the voting process
 * @notice End users do not interact directly with this contract (read-only)
 *
 * @dev The contract stores:
 *      - ongoing proposals
 *      - archived proposals
 *      - vote progress and result
 *      - vote parameters
 */
contract Agora is Extension, IAgora, Constants {
    using Slot for bytes28;

    struct Archive {
        uint32 archivedAt;
        address dataAddr;
    }

    /// @dev track proposals by their hash
    mapping(bytes32 => Proposal) private _proposals;

    /// @dev track vote parameters by their voteID
    mapping(bytes4 => VoteParam) private _voteParams;

    /// @dev track users vote contribution by proposals
    mapping(bytes32 => mapping(address => bool)) private _haveVoted;

    /// @dev track archived proposals by their hash
    mapping(bytes32 => Archive) private _archives;

    /**
     * @dev A default vote parameters is added a contract deployment
     *
     * @param core address of DaoCore
     */
    constructor(address core) Extension(core, Slot.AGORA) {
        _addVoteParam(VOTE_STANDARD, Consensus.TOKEN, 7 days, 3 days, 8000, 7 days);
    }

    /*//////////////////////////////////////////////////////////
                            PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Called by the VOTING adapter to commit an user's vote
     * @dev see {_submitVote}
     *
     * @param proposalId hash of the proposal to vote on
     * @param voter address of the user who vote
     * @param voteWeight weight of the vote to commit
     * @param value user's descision
     */
    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external onlyAdapter(Slot.VOTING) {
        _submitVote(proposalId, voter, voteWeight, value);
    }

    /**
     * @notice Called by any `adapter` which can submit proposals
     * to register a new proposal.
     * @dev The proposalId is a concatenation of the `adapter`
     * slotId (bytes4) and the hash of the adapter's proposal (bytes28).
     * A counter for vote parameter is incremented to avoid the removal
     * of vote parameter while used in a proposal.
     *
     * @param slot slotId of the adapter which send the proposal
     * @param adapterProposalId hash of the `adapter` proposal
     * @param adminApproved inform if an admin need to approve the proposal
     * @param voteParamId vote parameter to use for this proposal
     * @param minStartTime timestamp for the start of the voting period
     * @param initiater address of user who initiated this proposal
     */
    function submitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproved,
        bytes4 voteParamId,
        uint32 minStartTime,
        address initiater
    ) external onlyAdapter(slot) {
        bytes32 proposalId = adapterProposalId.concatWithSlot(slot);
        Proposal memory proposal_ = _proposals[proposalId];
        require(!proposal_.active, "Agora: proposal already exist");

        require(_voteParams[voteParamId].votingPeriod > 0, "Agora: unknown vote params");

        uint32 timestamp = uint32(block.timestamp);

        if (minStartTime == 0) minStartTime = timestamp;
        require(minStartTime >= timestamp, "Agora: wrong starting time");

        proposal_.active = true;
        proposal_.adminApproved = adminApproved;
        proposal_.createdAt = timestamp;
        proposal_.minStartTime = minStartTime;
        proposal_.initiater = initiater;
        proposal_.voteParamId = voteParamId;

        _proposals[proposalId] = proposal_;
        ++_voteParams[voteParamId].usesCount;

        emit ProposalSubmitted(slot, initiater, voteParamId, proposalId);
    }

    /**
     * @notice Called by the `adapter` which has sent the proposal, the
     * function flag the proposal as proceeded and archive it.
     *
     * @dev The result of the proposal is already check before calling
     * this function and the result is reported here with {accepted}.
     *
     * @param proposalId proposal to finalize
     * @param finalizer address of user who called {finalizeProposal}
     * @param accepted result of the vote, reported by the adapter
     */
    function finalizeProposal(
        bytes32 proposalId,
        address finalizer,
        bool accepted
    ) external onlyAdapter(bytes4(proposalId)) {
        _proposals[proposalId].proceeded = true;
        _archives[proposalId] = Archive(uint32(block.timestamp), msg.sender);
        emit ProposalFinalized(proposalId, finalizer, accepted);
    }

    /**
     * @notice Called by VOTING adapter to delete an archived
     * proposal.
     *
     * @dev This function is not fully implemented, the second
     * parameter is set to reward the user who send a transaction
     * to delete the archive.
     * The archive is deleted in the Agora contract, from {_archives},
     * and in the corresponding contract address, where the proposal
     * datas are stored.
     *
     * NOTE In the future this function should be in interaction with a
     * "reward/reputation" module.
     *
     * @param proposalId proposal to delete
     * @param (address) user who initiated the call
     */
    function deleteArchive(bytes32 proposalId, address) external onlyAdapter(Slot.VOTING) {
        Archive memory archive_ = _archives[proposalId];
        require(archive_.archivedAt > 0, "Agora: not an archive");
        require(block.timestamp >= archive_.archivedAt + 365 days, "Agora: not archivable");
        IProposerAdapter(archive_.dataAddr).deleteArchive(proposalId);
        delete _archives[proposalId];

        // reward user here
    }

    /**
     * @notice Called by VOTING adapter to add or replace a vote parameters
     *
     * @param isToAdd flag for adding or removing the parameter
     * @param voteParamId id of the vote
     * @param consensus vote consensus type
     * @param votingPeriod voting period
     * @param gracePeriod grace period
     * @param threshold threshold of the vote acceptance (in basis point)
     * @param adminValidationPeriod admin grace period before the voting period
     */
    function changeVoteParam(
        bool isToAdd,
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external onlyAdapter(Slot.VOTING) {
        if (isToAdd) {
            _addVoteParam(
                voteParamId,
                consensus,
                votingPeriod,
                gracePeriod,
                threshold,
                adminValidationPeriod
            );
            return;
        }

        _removeVoteParam(voteParamId);
    }

    /**
     * @notice Called by VOTING adapter to approve a proposal before the
     * voting period
     * @dev The check for admin-only is done in the VOTING adapter.
     * The function postpone the starting time to not reduce the voting period
     * of the proposal.
     *
     * @param proposalId proposal to approve
     */
    function validateProposal(bytes32 proposalId) external onlyAdapter(Slot.VOTING) {
        require(
            _evaluateProposalStatus(proposalId) == ProposalStatus.VALIDATION,
            "Agora: no validation required"
        );
        Proposal memory proposal_ = _proposals[proposalId];
        _proposals[proposalId].adminApproved = true;

        // postpone the `minStartTime` to now if passed
        uint256 timestamp = block.timestamp;
        if (proposal_.minStartTime < timestamp) {
            proposal_.minStartTime = uint32(timestamp);
        }
    }

    /**
     * @notice Called by VOTING adapter to suspend a proposal.
     * @dev The check for admin-only is done in the VOTING adapter.
     * The function pay attention when the proposal is suspended to
     * postpone and so not reduce the voting period if the proposal is
     * resumed.
     *
     * @param proposalId proposal to suspend
     */
    function suspendProposal(bytes32 proposalId) external onlyAdapter(Slot.VOTING) {
        ProposalStatus status = _evaluateProposalStatus(proposalId);
        require(
            status == ProposalStatus.STANDBY ||
                status == ProposalStatus.VALIDATION ||
                status == ProposalStatus.ONGOING ||
                status == ProposalStatus.CLOSED,
            "Agora: cannot suspend the proposal"
        );

        if (status == ProposalStatus.ONGOING) {
            _proposals[proposalId].suspendedAt = uint32(block.timestamp);
        } else if (status == ProposalStatus.CLOSED) {
            // flag when the proposal is suspended
            _proposals[proposalId].suspendedAt = 1;
        }
        _proposals[proposalId].suspended = true;
    }

    /**
     * @notice Called by VOTING adapter to unsuspend a proposal.
     * @dev The check for admin-only is done in the VOTING adapter.
     * Unsuspend and increase the voting period if needed.
     *
     * @param proposalId proposal to unsuspend
     */
    function unsuspendProposal(bytes32 proposalId) external onlyAdapter(Slot.VOTING) {
        Proposal memory proposal_ = _proposals[proposalId];
        require(proposal_.suspended, "Agora: proposal not suspended");
        uint256 timestamp = block.timestamp;

        proposal_.adminApproved = true;
        proposal_.suspended = false;
        if (proposal_.suspendedAt == 0) {
            // only if suspended in STANDBY or VALIDATION
            proposal_.minStartTime = uint32(timestamp);
        } else if (proposal_.suspendedAt > 1) {
            // postpone voting period if suspended in ONGOING
            proposal_.shiftedTime += uint32(timestamp - proposal_.suspendedAt);
        }

        _proposals[proposalId] = proposal_;
    }

    /*//////////////////////////////////////////////////////////
                            PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Get the current status of a proposal.
     * @dev see {_evaluateProposalStatus}
     * @param proposalId proposal to check
     * @return proposal status ({ProposalStatus} enum)
     */
    function getProposalStatus(bytes32 proposalId) external view returns (ProposalStatus) {
        return _evaluateProposalStatus(proposalId);
    }

    /**
     * @notice Get the current vote result.
     * @dev see {_calculateVoteResult}
     * @param proposalId proposal to check
     * @return accepted true if the proposal is accepted
     */
    function getVoteResult(bytes32 proposalId) external view returns (bool accepted) {
        return _calculateVoteResult(proposalId);
    }

    /**
     * @notice Get proposal details
     * @param proposalId proposal to check
     * @return struct {Proposal}
     */
    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    /**
     * @notice Get vote parameters details
     * @param voteParamId voteId to check (bytes4)
     * @return struct {VoteParam}
     */
    function getVoteParams(bytes4 voteParamId) external view returns (VoteParam memory) {
        return _voteParams[voteParamId];
    }

    /**
     * @notice Check if an user has voted for a proposal
     * @param proposalId proposal to check
     * @param voter user address
     * @return true if user has voted for this proposal
     * */
    function hasVoted(bytes32 proposalId, address voter) external view returns (bool) {
        return _haveVoted[proposalId][voter];
    }

    /*//////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to add a vote parameter.
     * {threshold} use basis point (10000 = 100%)
     * A vote parameter cannot be replaced
     *
     * @param voteParamId id of the vote
     * @param consensus vote consensus type
     * @param votingPeriod voting period
     * @param gracePeriod grace period
     * @param threshold threshold of the vote acceptance (in basis point)
     * @param adminValidationPeriod admin grace period before the voting period
     */
    function _addVoteParam(
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) internal {
        VoteParam memory voteParam_ = _voteParams[voteParamId];
        require(voteParam_.consensus == Consensus.UNINITIATED, "Agora: cannot replace params");

        require(consensus != Consensus.UNINITIATED, "Agora: bad consensus");
        require(votingPeriod > 0, "Agora: below min period");
        require(threshold <= 10000, "Agora: wrong threshold or below min value");

        voteParam_.consensus = consensus;
        voteParam_.votingPeriod = votingPeriod;
        voteParam_.gracePeriod = gracePeriod;
        voteParam_.threshold = threshold;
        voteParam_.adminValidationPeriod = adminValidationPeriod;

        _voteParams[voteParamId] = voteParam_;

        emit VoteParamsChanged(voteParamId, true);
    }

    /**
     * @dev Internal function to remove a vote parameter.
     * The vote parameter cannot be removed if it used in an
     * ongoing proposal
     *
     * @param voteParamId id of the vote
     */
    function _removeVoteParam(bytes4 voteParamId) internal {
        uint256 usesCount = _voteParams[voteParamId].usesCount;
        require(usesCount == 0, "Agora: parameters still used");

        delete _voteParams[voteParamId];
        emit VoteParamsChanged(voteParamId, false);
    }

    /**
     * @dev Check is the voting period is live, if the user
     * has not vote already, and increment the score on the
     * corresponding proposal.
     *
     * @param proposalId proposal to vote on
     * @param voter user who vote
     * @param voteWeight weight of the user vote
     * @param value user descision
     */
    function _submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) internal {
        require(
            _evaluateProposalStatus(proposalId) == ProposalStatus.ONGOING,
            "Agora: outside voting period"
        );

        require(!_haveVoted[proposalId][voter], "Agora: proposal voted");
        _haveVoted[proposalId][voter] = true;

        Proposal memory proposal_ = _proposals[proposalId];

        if (_voteParams[proposal_.voteParamId].consensus == Consensus.MEMBER) {
            voteWeight = 1;
        }

        require(value <= 2, "Agora: neither (y), (n), (nota)");
        ++proposal_.score.memberVoted;
        if (value == 0) {
            proposal_.score.nbYes += voteWeight;
        } else if (value == 1) {
            proposal_.score.nbNo += voteWeight;
        } else {
            proposal_.score.nbNota += voteWeight;
        }

        _proposals[proposalId] = proposal_;
        emit MemberVoted(proposalId, voter, value, voteWeight);
    }

    /**
     * @dev Internal checker to calculate the vote result
     *
     * NOTE NOTA votes are not integrated in the calculation,
     * this vote is only used to inform user committments to
     * the DAO descisions.
     *
     * @param proposalId proposal to check
     * @return accepted true if the proposal is accepted
     */
    function _calculateVoteResult(bytes32 proposalId) internal view returns (bool accepted) {
        Proposal memory proposal_ = _proposals[proposalId];
        Score memory score_ = proposal_.score;
        // how to integrate NOTA vote, should it be?
        uint256 totalVote = score_.nbYes + score_.nbNo;

        return
            totalVote != 0 &&
            (score_.nbYes * 10000) / totalVote >= _voteParams[proposal_.voteParamId].threshold;
    }

    /**
     * @dev Internal function to evaluate the status of the proposal.
     * The current timestamp is compared to different period registered in
     * the vote parameter and the proposal to determine the status.
     *
     * @param proposalId proposal to check
     * @return proposal status ({ProposalStatus} enum)
     */
    function _evaluateProposalStatus(bytes32 proposalId) internal view returns (ProposalStatus) {
        Proposal memory proposal_ = _proposals[proposalId];
        VoteParam memory voteParam_ = _voteParams[proposal_.voteParamId];
        uint256 timestamp = block.timestamp;

        // proposal exist?
        if (!proposal_.active) {
            return ProposalStatus.UNKNOWN;
        }

        // is suspended?
        if (proposal_.suspended) {
            return ProposalStatus.SUSPENDED;
        }

        // is approved by admin?
        if (!proposal_.adminApproved) {
            uint256 endOfValidationPeriod = proposal_.createdAt + voteParam_.adminValidationPeriod;
            if (timestamp < endOfValidationPeriod) {
                return ProposalStatus.VALIDATION;
            } else {
                // virtualy postpone the `minStartTime`
                if (proposal_.minStartTime < endOfValidationPeriod) {
                    proposal_.minStartTime = uint32(endOfValidationPeriod);
                }
            }
        }

        // has started?
        if (timestamp < proposal_.minStartTime) {
            return ProposalStatus.STANDBY;
        }

        // is in voting period?
        if (timestamp < proposal_.minStartTime + proposal_.shiftedTime + voteParam_.votingPeriod) {
            return ProposalStatus.ONGOING;
        }

        // is in grace period?
        if (
            timestamp <
            proposal_.minStartTime +
                proposal_.shiftedTime +
                voteParam_.votingPeriod +
                voteParam_.gracePeriod
        ) {
            return ProposalStatus.CLOSED;
        }

        // is finalized
        if (!proposal_.proceeded) {
            return ProposalStatus.TO_FINALIZE;
        } else {
            return ProposalStatus.ARCHIVED;
        }
    }
}
