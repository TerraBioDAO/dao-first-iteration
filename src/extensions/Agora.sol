// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/Extension.sol";
import "../helpers/Constants.sol";
import "../interfaces/IAgora.sol";
import "../interfaces/IProposerAdapter.sol";
import "../helpers/Constants.sol";

/**
 * @notice contract which store votes parameters, vote result,
 * proposals and their status
 */

contract Agora is Extension, IAgora, Constants {
    using Slot for bytes28;

    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes4 => VoteParam) private _voteParams;
    mapping(bytes32 => mapping(address => bool)) private _votes;

    constructor(address core) Extension(core, Slot.AGORA) {
        _addVoteParam(VOTE_STANDARD, Consensus.TOKEN, 7 days, 3 days, 8000, 7 days);
    }

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external onlyAdapter(Slot.VOTING) {
        _submitVote(proposalId, voter, voteWeight, value);
    }

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
        ++_voteParams[voteParamId].utilisation;

        emit ProposalSubmitted(slot, initiater, voteParamId, proposalId);
    }

    // Can be called by any member from VOTING adapter
    function finalizeProposal(
        bytes32 proposalId,
        address finalizer,
        VoteResult voteResult
    ) external onlyAdapter(Slot.VOTING) {
        _proposals[proposalId].proceeded = true;
        emit ProposalFinalized(proposalId, finalizer, voteResult);
    }

    function changeVoteParams(
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external onlyAdapter(Slot.VOTING) {
        if (consensus == Consensus.NO_VOTE) {
            _removeVoteParam(voteParamId);
        } else {
            _addVoteParam(
                voteParamId,
                consensus,
                votingPeriod,
                gracePeriod,
                threshold,
                adminValidationPeriod
            );
        }
    }

    function validateProposal(bytes32 proposalId) external onlyAdapter(Slot.VOTING) {
        require(
            _evaluateProposalStatus(proposalId) == ProposalStatus.VALIDATION,
            "Agora: no validation required"
        );
        Proposal memory proposal_ = _proposals[proposalId];
        _proposals[proposalId].adminApproved = true;

        uint256 timestamp = block.timestamp;
        if (timestamp > proposal_.minStartTime) {
            proposal_.shiftedTime += uint32(timestamp - proposal_.minStartTime);
        }
        // should postpone voting period!
    }

    /* //////////////////////////
                GETTERS
    ////////////////////////// */
    function getProposalStatus(bytes32 proposalId) external view returns (ProposalStatus) {
        return _evaluateProposalStatus(proposalId);
    }

    function getVoteResult(bytes32 proposalId) external view returns (VoteResult) {
        return _calculVoteResult(proposalId);
    }

    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    function getVoteParams(bytes4 voteParamId) external view returns (VoteParam memory) {
        return _voteParams[voteParamId];
    }

    function getVotes(bytes32 proposalId, address voter) external view returns (bool) {
        return _votes[proposalId][voter];
    }

    function _addVoteParam(
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) internal {
        VoteParam memory voteParam_ = _voteParams[voteParamId];
        require(voteParam_.consensus == Consensus.NO_VOTE, "Agora: cannot replace params");

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

    function _removeVoteParam(bytes4 voteParamId) internal {
        uint256 utilisation = _voteParams[voteParamId].utilisation;
        require(utilisation == 0, "Agora: parameters still used");

        delete _voteParams[voteParamId];
        emit VoteParamsChanged(voteParamId, false);
    }

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

        require(!_votes[proposalId][voter], "Agora: proposal voted");
        _votes[proposalId][voter] = true;

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

    function _calculVoteResult(bytes32 proposalId) internal view returns (VoteResult) {
        Proposal memory proposal_ = _proposals[proposalId];
        Score memory score_ = proposal_.score;
        // how to integrate NOTA vote, should it be?
        uint256 totalVote = score_.nbYes + score_.nbYes;

        if (
            totalVote != 0 &&
            (score_.nbYes * 10000) / totalVote >= _voteParams[proposal_.voteParamId].threshold
        ) {
            return VoteResult.ACCEPTED;
        } else {
            return VoteResult.REJECTED;
        }
    }

    function _evaluateProposalStatus(bytes32 proposalId) internal view returns (ProposalStatus) {
        Proposal memory proposal_ = _proposals[proposalId];
        VoteParam memory voteParam_ = _voteParams[proposal_.voteParamId];
        uint256 timestamp = block.timestamp;

        // pps exist?
        if (!proposal_.active) {
            return ProposalStatus.UNKNOWN;
        }

        // is validated?
        if (timestamp < proposal_.createdAt + voteParam_.adminValidationPeriod) {
            if (!proposal_.adminApproved) {
                return ProposalStatus.VALIDATION;
            }
        }

        // has started
        if (timestamp < proposal_.minStartTime) {
            return ProposalStatus.STANDBY;
        }

        // is suspended
        if (proposal_.suspended) {
            return ProposalStatus.SUSPENDED;
        }

        // is in voting period
        if (timestamp < proposal_.minStartTime + proposal_.shiftedTime + voteParam_.votingPeriod) {
            return ProposalStatus.ONGOING;
        }

        // is in grace period
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
