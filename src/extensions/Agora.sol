// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/Extension.sol";
import "../helpers/Constants.sol";
import "../interfaces/IAgora.sol";
import "../interfaces/IProposerAdapter.sol";
import "../helpers/Constants.sol";

contract Agora is Extension, IAgora, Constants {
    using Slot for bytes28;

    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes4 => VoteParam) private _voteParams;
    mapping(bytes32 => mapping(address => bool)) private _votes;

    constructor(address core) Extension(core, Slot.AGORA) {
        _addVoteParam(VOTE_STANDARD, Consensus.TOKEN, 7 days, 3 days, 8000, 7 days);
    }

    function submitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproved,
        bytes4 voteParamId,
        uint32 minStartTime,
        address initiater
    ) external onlyAdapter(slot) {
        bytes32 _proposalId = adapterProposalId.concatWithSlot(slot);
        Proposal memory _proposal = _proposals[_proposalId];
        require(!_proposal.active, "Agora: proposal already exist");

        VoteParam memory _voteParam = _voteParams[voteParamId];
        require(_voteParam.votingPeriod > 0, "Agora: unknown vote params");

        uint32 timestamp = uint32(block.timestamp);

        if (minStartTime == 0) minStartTime = timestamp;
        require(minStartTime >= timestamp, "Agora: wrong starting time");

        _proposal.active = true;
        _proposal.adminApproved = adminApproved;
        _proposal.createdAt = timestamp;
        _proposal.minStartTime = minStartTime;
        _proposal.initiater = initiater;
        _proposal.voteParamId = voteParamId;

        _proposals[_proposalId] = _proposal;
        ++_voteParams[voteParamId].utilisation;

        emit ProposalSubmitted(slot, initiater, voteParamId, _proposalId);
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

    // Can be called by any member from VOTING adapter
    function finalizeProposal(
        bytes32 proposalId,
        address finalizer,
        VoteResult voteResult
    ) external onlyAdapter(Slot.VOTING) {
        _proposals[proposalId].proceeded = true;
        emit ProposalFinalized(proposalId, finalizer, voteResult);
    }

    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external onlyAdapter(Slot.VOTING) {
        _submitVote(proposalId, voter, voteWeight, value);
    }

    function calculVoteResult(bytes32 proposalId) internal view returns (VoteResult) {
        Proposal memory proposal = _proposals[proposalId];
        Score memory score = proposal.score;
        // how to integrate NOTA vote, should it be?
        uint256 totalVote = score.nbYes + score.nbYes;

        if (
            totalVote != 0 &&
            (score.nbYes * 10000) / totalVote >= _voteParams[proposal.voteParamId].threshold
        ) {
            return VoteResult.ACCEPTED;
        } else {
            return VoteResult.REJECTED;
        }
    }

    function evaluateProposalStatus(bytes32 proposalId) internal view returns (ProposalStatus) {
        Proposal memory _proposal = _proposals[proposalId];
        VoteParam memory _voteParam = _voteParams[_proposal.voteParamId];
        uint256 timestamp = block.timestamp;

        // pps exist?
        if (!_proposal.active) {
            return ProposalStatus.UNKNOWN;
        }

        // is validated?
        if (timestamp < _proposal.createdAt + _voteParam.adminValidationPeriod) {
            if (!_proposal.adminApproved) {
                return ProposalStatus.VALIDATION;
            }
        }

        // has started
        if (timestamp < _proposal.minStartTime) {
            return ProposalStatus.STANDBY;
        }

        // is suspended
        if (_proposal.suspended) {
            return ProposalStatus.SUSPENDED;
        }

        // is in voting period
        if (timestamp < _proposal.minStartTime + _proposal.shiftedTime + _voteParam.votingPeriod) {
            return ProposalStatus.ONGOING;
        }

        // is in grace period
        if (
            timestamp <
            _proposal.minStartTime +
                _proposal.shiftedTime +
                _voteParam.votingPeriod +
                _voteParam.gracePeriod
        ) {
            return ProposalStatus.CLOSED;
        }

        // is finalized
        if (!_proposal.proceeded) {
            return ProposalStatus.TO_FINALIZE;
        } else {
            return ProposalStatus.ARCHIVED;
        }
    }

    // GETTERS
    function getProposalStatus(bytes32 proposalId) external view returns (ProposalStatus) {
        return evaluateProposalStatus(proposalId);
    }

    function getVoteResult(bytes32 proposalId) external view returns (VoteResult) {
        return calculVoteResult(proposalId);
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

    // INTERNAL FUNCTION

    function _addVoteParam(
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) internal {
        VoteParam memory _voteParam = _voteParams[voteParamId];
        require(_voteParam.consensus == Consensus.NO_VOTE, "Agora: cannot replace params");

        require(votingPeriod > 0, "Agora: below min period");
        require(threshold <= 10000, "Agora: wrong threshold or below min value");

        _voteParam.consensus = consensus;
        _voteParam.votingPeriod = votingPeriod;
        _voteParam.gracePeriod = gracePeriod;
        _voteParam.threshold = threshold;
        _voteParam.adminValidationPeriod = adminValidationPeriod;

        _voteParams[voteParamId] = _voteParam;

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
            evaluateProposalStatus(proposalId) == ProposalStatus.ONGOING,
            "Agora: outside voting period"
        );

        require(!_votes[proposalId][voter], "Agora: proposal voted");
        _votes[proposalId][voter] = true;

        Proposal memory _proposal = _proposals[proposalId];

        if (_voteParams[_proposal.voteParamId].consensus == Consensus.MEMBER) {
            voteWeight = 1;
        }

        require(value <= 2, "Agora: neither (y), (n), (nota)");
        ++_proposal.score.memberVoted;
        if (value == 0) {
            _proposal.score.nbYes += voteWeight;
        } else if (value == 1) {
            _proposal.score.nbNo += voteWeight;
        } else {
            _proposal.score.nbNota += voteWeight;
        }

        _proposals[proposalId] = _proposal;
        emit MemberVoted(proposalId, voter, value, voteWeight);
    }
}
