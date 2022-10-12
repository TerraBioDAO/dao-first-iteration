// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../guards/CoreGuard.sol";
import "../helpers/ScoreUtils.sol";
import "../extensions/IAgora.sol";

contract Agora is IAgora, CoreGuard {
    using ScoreUtils for uint256;

    event VoteParamsChanged(bytes4 indexed voteId, bool indexed added); // add consensus?

    event ProposalSubmitted(
        bytes4 indexed slot,
        address indexed from,
        bytes4 indexed voteParam,
        bytes32 proposalId
    );

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
        bool executable,
        bytes4 voteId,
        uint64 startTime,
        address initiater
    ) external onlyAdapter(slot) {
        VoteParam memory vote = voteParams[voteId];
        require(vote.votingPeriod > 0, "Agora: unknown vote params");

        if (startTime == 0) startTime = uint64(block.timestamp);
        require(startTime >= block.timestamp, "Agora: wrong starting time");

        proposals[bytes32(bytes.concat(slot, proposalId))] = Proposal(
            slot,
            proposalId,
            executable,
            startTime,
            startTime + vote.votingPeriod,
            0,
            ProposalStatus.ONGOING,
            vote,
            initiater
        );

        emit ProposalSubmitted(slot, initiater, voteId, proposalId);
    }

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        VoteType voteType,
        uint64 votingPeriod,
        uint64 gracePeriod,
        uint64 threshold,
        bool adminValidation
    ) external onlyAdapter(Slot.VOTING) {
        if (consensus == Consensus.NO_VOTE) {
            _removeVoteParam(voteId);
        } else {
            _addVoteParam(
                voteId,
                consensus,
                voteType,
                votingPeriod,
                gracePeriod,
                threshold,
                adminValidation
            );
        }
    }

    function processProposal(bytes4 slot, bytes28 proposalId) external onlyAdapter(Slot.VOTING) {
        IDaoCore core = IDaoCore(_core);
        IAdapter adapter = IAdapter(core.getSlotContractAddr(slot));
        adapter.processProposal(bytes32(bytes.concat(slotId, proposalId)));
    }

    function changeProposalStatus(bytes32 proposalId, ProposalStatus newStatus)
        external
        onlyAdapter(bytes4(proposalId))
    {
        Proposal storage proposal = proposals[proposalId];
        proposal.status = newStatus;
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
        VoteType voteType,
        uint64 votingPeriod,
        uint64 gracePeriod,
        uint64 threshold,
        bool adminValidation
    ) internal {
        VoteParam memory vote = voteParams[voteId];
        require(vote.consensus == Consensus.NO_VOTE, "Agora: cannot replace params");

        require(votingPeriod > 0, "Agora: below min period");
        require(threshold <= 10000, "Agora: wrong threshold or below min value");

        vote.consensus = consensus;
        vote.voteType = voteType;
        vote.votingPeriod = votingPeriod;
        vote.gracePeriod = gracePeriod;
        vote.threshold = threshold;
        vote.adminValidation = adminValidation;

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
        require(p.status == ProposalStatus.ONGOING, "Agora: unknown proposal");
        require(
            p.startTime <= block.timestamp && p.endTime > block.timestamp,
            "Agora: outside voting period"
        );

        require(!votes[proposalId][voter], "Agora: proposal voted");
        votes[proposalId][voter] = true;

        if (p.params.consensus == Consensus.MEMBER) {
            voteWeight = 1;
        }
        uint256 score = p.score;

        if (p.params.voteType == VoteType.YES_NO) {
            // YES / NO vote type
            require(value <= 1, "Agora: neither (y) nor (n)");

            score = value == 1
                ? score.yesNoIncrement(voteWeight, 0)
                : score.yesNoIncrement(0, voteWeight);
        } else if (p.params.voteType == VoteType.PREFERENCE) {
            revert("NOT IMPLEMENTED YET");
        } else {
            revert("NOT IMPLEMENTED YET");
        }

        // update score
        p.score = score;

        // Should implement total vote count?

        proposals[proposalId] = p;
        emit MemberVoted(proposalId, voter, value, voteWeight);
    }
}
