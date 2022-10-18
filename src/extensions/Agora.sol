// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../guards/CoreGuard.sol";
import "../extensions/IAgora.sol";

contract Agora is IAgora, CoreGuard {
    event VoteParamsChanged(bytes4 indexed voteId, bool indexed added); // add consensus?

    event ProposalSubmitted(
        bytes4 indexed slot,
        address indexed from,
        bytes4 indexed voteParam,
        bytes32 proposalId
    );

    event ProposalExecuted(bytes4 indexed slot, bytes28 indexed proposalId);

    event MemberVoted(
        bytes32 indexed proposalId,
        address indexed voter,
        uint256 indexed value,
        uint256 voteWeight
    );

    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes4 => VoteParam) public voteParams;
    mapping(bytes32 => mapping(address => bool)) public votes;

    constructor(address core) CoreGuard(core, Slot.AGORA) {}

    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bool adminValidation,
        bool executable,
        bytes4 voteId,
        uint32 startTime,
        address initiater
    ) external onlyAdapter(slot) {
        VoteParam memory vote = voteParams[voteId];
        require(vote.votingPeriod > 0, "Agora: unknown vote params");

        if (startTime == 0) startTime = uint32(block.timestamp);
        require(startTime >= block.timestamp, "Agora: wrong starting time");

        Score memory defaultScore;
        proposals[bytes32(bytes.concat(slot, proposalId))] = Proposal(
            true,
            adminValidation,
            executable,
            false,
            startTime,
            startTime + vote.votingPeriod,
            initiater,
            defaultScore,
            vote
        );

        emit ProposalSubmitted(slot, initiater, voteId, proposalId);
    }

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint64 threshold
    ) external onlyAdapter(Slot.VOTING) {
        if (consensus == Consensus.NO_VOTE) {
            _removeVoteParam(voteId);
        } else {
            _addVoteParam(voteId, consensus, votingPeriod, gracePeriod, threshold);
        }
    }

    // Can be called by any member from VOTING adapter
    function processProposal(bytes4 slot, bytes28 proposalId) external onlyAdapter(Slot.VOTING) {
        bytes32 pId = bytes32(bytes.concat(slotId, proposalId));
        Proposal storage proposal = proposals[pId];
        require(
            proposal.executable && getProposalStatus(pId) == IAgora.ProposalStatus.TO_PROCEED,
            "Agora: can't proceed"
        );

        // proposal.status = IAgora.ProposalStatus.EXECUTED;

        IDaoCore core = IDaoCore(_core);
        IAdapter adapter = IAdapter(core.getSlotContractAddr(slot));
        require(address(adapter) != address(0), "Agora: adapter not found");

        bool success = adapter.processProposal(bytes32(bytes.concat(slotId, proposalId)));

        if (!success) {
            revert();
        }

        emit ProposalExecuted(slot, bytes28(proposalId << 32));
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
        return ProposalStatus.ONGOING;
    }

    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
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
        uint64 threshold
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
        Proposal memory p = proposals[proposalId];
        require(p.active, "Agora: unknown proposal");
        require(
            p.startTime <= block.timestamp && p.endTime > block.timestamp,
            "Agora: outside voting period"
        );

        require(!votes[proposalId][voter], "Agora: proposal voted");
        votes[proposalId][voter] = true;

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

        proposals[proposalId] = p;
        emit MemberVoted(proposalId, voter, value, voteWeight);
    }
}
