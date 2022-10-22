// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/CoreExtension.sol";
import "../interfaces/IAgora.sol";
import "../interfaces/IProposerAdapter.sol";

contract Agora is CoreExtension, IAgora {
    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes4 => VoteParam) private _voteParams;
    mapping(bytes32 => mapping(address => bool)) private _votes;

    constructor(address core) CoreExtension(core, Slot.AGORA) {
        _addVoteParam(
            Slot.VOTE_STANDARD,
            Consensus.TOKEN,
            7 * Slot.DAY,
            3 * Slot.DAY,
            8000,
            7 * Slot.DAY
        );
    }

    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bool adminApproved,
        bool executable,
        bytes4 voteId,
        uint32 minStartTime,
        address initiater
    ) external onlyAdapter(slot) {
        bytes32 _proposalId = bytes32(bytes.concat(slot, proposalId));
        Proposal memory _proposal = _proposals[_proposalId];
        require(!_proposal.active, "Agora: proposal already exist");

        VoteParam memory vote = _voteParams[voteId];
        require(vote.votingPeriod > 0, "Agora: unknown vote params");

        uint32 timestamp = uint32(block.timestamp);

        if (minStartTime == 0) minStartTime = timestamp;
        require(minStartTime >= timestamp, "Agora: wrong starting time");

        _proposal.active = true;
        _proposal.adminApproved = adminApproved;
        _proposal.createdAt = timestamp;
        _proposal.executable = executable;
        _proposal.minStartTime = minStartTime;
        _proposal.initiater = initiater;
        _proposal.voteId = voteId;

        _proposals[proposalId] = _proposal;
        ++_voteParams[voteId].utilisation;

        emit ProposalSubmitted(slot, initiater, voteId, _proposalId);
    }

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external onlyAdapter(Slot.VOTING) {
        if (consensus == Consensus.NO_VOTE) {
            _removeVoteParam(voteId);
        } else {
            _addVoteParam(
                voteId,
                consensus,
                votingPeriod,
                gracePeriod,
                threshold,
                adminValidationPeriod
            );
        }
    }

    // Can be called by any member from VOTING adapter
    function finalizeProposal(bytes32 proposalId, address finalizer)
        external
        onlyAdapter(Slot.VOTING)
    {
        require(
            getProposalStatus(proposalId) == ProposalStatus.TO_FINALIZE,
            "Agora: cannot be finalized"
        );

        Proposal memory _proposal = _proposals[proposalId];
        VoteResult result = _calculVoteResult(
            _proposal.score,
            _voteParams[_proposal.voteId].threshold
        );

        if (result == VoteResult.ACCEPTED && _proposal.executable) {
            address adapter = IDaoCore(_core).getSlotContractAddr(bytes4(proposalId));
            // This should not be possible, block slot entry when proposals ongoing
            require(adapter != address(0), "Agora: adapter not found");

            IProposerAdapter(adapter).executeProposal(proposalId);
            // error should be handled here
        }
        _proposal.proceeded = true;

        // reward for finalizer

        _proposals[proposalId] = _proposal;
        emit ProposalFinalized(proposalId, result, finalizer);
    }

    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external onlyAdapter(Slot.VOTING) {
        _submitVote(proposalId, voter, voteWeight, value);
    }

    // GETTERS
    function getProposalStatus(bytes32 proposalId) public view returns (ProposalStatus) {
        Proposal memory _proposal = _proposals[proposalId];
        VoteParam memory _voteParam = _voteParams[_proposal.voteId];
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

    function getVoteResult(bytes32 proposalId) external view returns (VoteResult) {
        Proposal memory _proposal = _proposals[proposalId];
        return _calculVoteResult(_proposal.score, _voteParams[_proposal.voteId].threshold);
    }

    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    function getVoteParams(bytes4 voteId) external view returns (VoteParam memory) {
        return _voteParams[voteId];
    }

    function getVotes(bytes32 proposalId, address voter) external view returns (bool) {
        return _votes[proposalId][voter];
    }

    // INTERNAL FUNCTION

    function _addVoteParam(
        bytes4 voteId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) internal {
        VoteParam memory _voteParam = _voteParams[voteId];
        require(_voteParam.consensus == Consensus.NO_VOTE, "Agora: cannot replace params");

        require(votingPeriod > 0, "Agora: below min period");
        require(threshold <= 10000, "Agora: wrong threshold or below min value");

        _voteParam.consensus = consensus;
        _voteParam.votingPeriod = votingPeriod;
        _voteParam.gracePeriod = gracePeriod;
        _voteParam.threshold = threshold;
        _voteParam.adminValidationPeriod = adminValidationPeriod;

        _voteParams[voteId] = _voteParam;

        emit VoteParamsChanged(voteId, true);
    }

    function _removeVoteParam(bytes4 voteId) internal {
        uint256 utilisation = _voteParams[voteId].utilisation;
        require(utilisation == 0, "Agora: parameters still used");

        delete _voteParams[voteId];
        emit VoteParamsChanged(voteId, false);
    }

    function _submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) internal {
        require(
            getProposalStatus(proposalId) == ProposalStatus.ONGOING,
            "Agora: outside voting period"
        );

        require(!_votes[proposalId][voter], "Agora: proposal voted");
        _votes[proposalId][voter] = true;

        Proposal memory _proposal = _proposals[proposalId];

        if (_voteParams[_proposal.voteId].consensus == Consensus.MEMBER) {
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

    function _calculVoteResult(Score memory score, uint32 threshold)
        internal
        pure
        returns (VoteResult)
    {
        // how to integrate NOTA vote, should it be?
        uint256 totalVote = score.nbYes + score.nbYes;

        if (totalVote != 0 && (score.nbYes * 10000) / totalVote >= threshold) {
            return VoteResult.ACCEPTED;
        } else {
            return VoteResult.REJECTED;
        }
    }
}
