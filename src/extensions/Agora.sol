// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../guards/CoreGuard.sol";
import "../extensions/IAgora.sol";

contract Agora is IAgora, CoreGuard {
    uint256 public immutable ADMIN_VALIDATION_PERIOD;

    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes4 => VoteParam) public voteParams;
    mapping(bytes32 => mapping(address => bool)) public votes;

    constructor(address core) CoreGuard(core, Slot.AGORA) {
        ADMIN_VALIDATION_PERIOD = 7 * 86400; // 7 days
    }

    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bool adminApproval,
        bool executable,
        bytes4 voteId,
        uint32 minStartTime,
        address initiater
    ) external onlyAdapter(slot) {
        bytes32 proposalId = bytes32(bytes.concat(slot, proposalId));
        Proposal memory p = _proposals[proposalId];
        require(!p.active, "Agora: proposal already exist");

        VoteParam memory vote = voteParams[voteId];
        require(vote.votingPeriod > 0, "Agora: unknown vote params");

        uint32 timestamp = uint32(block.timestamp);

        if (minStartTime == 0) minStartTime = timestamp;
        require(minStartTime >= timestamp, "Agora: wrong starting time");

        p.active = true;
        p.adminApproval = adminApproval;
        p.createdAt = timestamp;
        p.executable = executable;
        p.minStartTime = minStartTime;
        p.initiater = initiater;
        p.params = vote;

        _proposals[proposalId] = p;

        emit ProposalSubmitted(slot, initiater, voteId, proposalId);
    }

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold
    ) external onlyAdapter(Slot.VOTING) {
        if (consensus == Consensus.NO_VOTE) {
            _removeVoteParam(voteId);
        } else {
            _addVoteParam(voteId, consensus, votingPeriod, gracePeriod, threshold);
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
        VoteResult result = _calculVoteResult(p.score, p.params.threshold);

        if (result == VoteResult.ACCEPTED && p.executable) {
            address adapter = IDaoCore(_core).getSlotContractAddr(bytes4(proposalId));
            // This should not be possible, block slot entry when proposals ongoing
            require(adapter != address(0), "Agora: adapter not found");

            IAdapter(adapter).finalizeProposal(bytes28(proposalId << 32));
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
        uint256 timestamp = block.timestamp;

        // pps exist?
        if (!p.active) {
            return ProposalStatus.UNKNOWN;
        }

        // is validated?
        if (timestamp < p.createdAt + ADMIN_VALIDATION_PERIOD) {
            if (!p.adminApproval) {
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
        if (timestamp < p.minStartTime + p.shiftedTime + p.params.votingPeriod) {
            return ProposalStatus.ONGOING;
        }

        // is in grace period
        if (
            timestamp <
            p.minStartTime + p.shiftedTime + p.params.votingPeriod + p.params.gracePeriod
        ) {
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
        return _calculVoteResult(p.score, p.params.threshold);
    }

    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    function getVoteParams(bytes4 voteId) external view returns (VoteParam memory) {
        return voteParams[voteId];
    }

    // INTERNAL FUNCTION

    function _addVoteParam(
        bytes4 voteId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold
    ) internal {
        VoteParam memory vote = voteParams[voteId];
        require(vote.consensus == Consensus.NO_VOTE, "Agora: cannot replace params");

        require(votingPeriod > 0, "Agora: below min period");
        require(threshold <= 10000, "Agora: wrong threshold or below min value");

        vote.consensus = consensus;
        vote.votingPeriod = votingPeriod;
        vote.gracePeriod = gracePeriod;
        vote.threshold = threshold;

        voteParams[voteId] = vote;

        emit VoteParamsChanged(voteId, true);
    }

    function _removeVoteParam(bytes4 voteId) internal {
        uint256 utilisation = voteParams[voteId].utilisation;
        require(utilisation == 0, "Agora: parameters still used");

        delete voteParams[voteId];
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

        require(!votes[proposalId][voter], "Agora: proposal voted");
        votes[proposalId][voter] = true;

        Proposal memory p = _proposals[proposalId];

        if (p.params.consensus == Consensus.MEMBER) {
            voteWeight = 1;
        }

        require(value < 2, "Agora: neither (y), (n), (nota)");
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

        if ((score.nbYes * 10000) / totalVote >= threshold) {
            return VoteResult.ACCEPTED;
        } else {
            return VoteResult.REJECTED;
        }
    }
}
