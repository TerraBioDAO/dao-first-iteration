// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../abstracts/CoreExtension.sol";
import "../interfaces/IAgora.sol";
import "../interfaces/IProposerAdapter.sol";

contract Agora is CoreExtension, IAgora {
    uint256 public immutable ADMIN_VALIDATION_PERIOD;

    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes4 => VoteParam) private _voteParams;
    mapping(bytes32 => mapping(address => bool)) private _votes;

    constructor(address core) CoreExtension(core, Slot.AGORA) {
        ADMIN_VALIDATION_PERIOD = 7 * Slot.DAY; // 7 days
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
        bytes32 proposalId = bytes32(bytes.concat(slot, proposalId));
        Proposal memory p = _proposals[proposalId];
        require(!p.active, "Agora: proposal already exist");

        VoteParam memory vote = _voteParams[voteId];
        require(vote.votingPeriod > 0, "Agora: unknown vote params");

        uint32 timestamp = uint32(block.timestamp);

        if (minStartTime == 0) minStartTime = timestamp;
        require(minStartTime >= timestamp, "Agora: wrong starting time");

        p.active = true;
        p.adminApproved = adminApproved;
        p.createdAt = timestamp;
        p.executable = executable;
        p.minStartTime = minStartTime;
        p.initiater = initiater;
        p.voteId = voteId;

        _proposals[proposalId] = p;
        ++_voteParams[voteId].utilisation;

        emit ProposalSubmitted(slot, initiater, voteId, proposalId);
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

        Proposal memory p = _proposals[proposalId];
        VoteResult result = _calculVoteResult(p.score, _voteParams[p.voteId].threshold);

        if (result == VoteResult.ACCEPTED && p.executable) {
            address adapter = IDaoCore(_core).getSlotContractAddr(bytes4(proposalId));
            // This should not be possible, block slot entry when proposals ongoing
            require(adapter != address(0), "Agora: adapter not found");

            IProposerAdapter(adapter).executeProposal(proposalId);
            // error should be handled here
        }
        p.proceeded = true;

        // reward for finalizer

        _proposals[proposalId] = p;
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
        Proposal memory p = _proposals[proposalId];
        VoteParam memory vp = _voteParams[p.voteId];
        uint256 timestamp = block.timestamp;

        // pps exist?
        if (!p.active) {
            return ProposalStatus.UNKNOWN;
        }

        // is validated?
        if (timestamp < p.createdAt + ADMIN_VALIDATION_PERIOD) {
            if (!p.adminApproved) {
                return ProposalStatus.VALIDATION;
            }
        }

        // has started
        if (timestamp < p.minStartTime) {
            return ProposalStatus.STANDBY;
        }

        // is suspended
        if (p.suspended) {
            return ProposalStatus.SUSPENDED;
        }

        // is in voting period
        if (timestamp < p.minStartTime + p.shiftedTime + vp.votingPeriod) {
            return ProposalStatus.ONGOING;
        }

        // is in grace period
        if (timestamp < p.minStartTime + p.shiftedTime + vp.votingPeriod + vp.gracePeriod) {
            return ProposalStatus.CLOSED;
        }

        // is finalized
        if (!p.proceeded) {
            return ProposalStatus.TO_FINALIZE;
        } else {
            return ProposalStatus.ARCHIVED;
        }
    }

    function getVoteResult(bytes32 proposalId) external view returns (VoteResult) {
        Proposal memory p = _proposals[proposalId];
        return _calculVoteResult(p.score, _voteParams[p.voteId].threshold);
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
        VoteParam memory vote = _voteParams[voteId];
        require(vote.consensus == Consensus.NO_VOTE, "Agora: cannot replace params");

        require(votingPeriod > 0, "Agora: below min period");
        require(threshold <= 10000, "Agora: wrong threshold or below min value");

        vote.consensus = consensus;
        vote.votingPeriod = votingPeriod;
        vote.gracePeriod = gracePeriod;
        vote.threshold = threshold;
        vote.adminValidationPeriod = adminValidationPeriod;

        _voteParams[voteId] = vote;

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

        Proposal memory p = _proposals[proposalId];

        if (_voteParams[p.voteId].consensus == Consensus.MEMBER) {
            voteWeight = 1;
        }

        require(value <= 2, "Agora: neither (y), (n), (nota)");
        ++p.score.memberVoted;
        if (value == 0) {
            p.score.nbYes += voteWeight;
        } else if (value == 1) {
            p.score.nbNo += voteWeight;
        } else {
            p.score.nbNota += voteWeight;
        }

        _proposals[proposalId] = p;
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
