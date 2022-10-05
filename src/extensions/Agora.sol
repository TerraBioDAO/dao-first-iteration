// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../guards/CoreGuard.sol";

contract Agora is CoreGuard {
    event VoteParamsChanged(
        bytes4 indexed voteId,
        Consensus indexed consensus,
        bool indexed added
    );

    event ProposalSubmitted(
        bytes4 indexed slot,
        address indexed from,
        bytes4 indexed voteParam,
        bytes32 proposalId
    );

    enum ProposalStatus {
        UNKNOWN,
        EXISTS,
        SUSPENDED,
        ACCEPTED,
        REJECTED
    }
    enum Consensus {
        NO_VOTE,
        TOKEN,
        MEMBER
    }

    struct VoteParam {
        Consensus consensus;
        uint64 votingPeriod;
        uint64 gracePeriod;
        uint64 threshold;
        bool adminValidation;
    }

    struct Proposal {
        bytes4 slot;
        bytes28 proposalId;
        uint64 startTime;
        uint64 endTime;
        uint128 score;
        ProposalStatus status;
        VoteParam params;
        address initiater;
    }

    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes4 => VoteParam) public voteParams;

    constructor(address core) CoreGuard(core, Slot.AGORA) {}

    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bytes4 voteId,
        uint64 startTime,
        address initiater
    ) external onlyAdapter(slot) {
        VoteParam memory vote = voteParams[voteId];
        require(vote.votingPeriod > 0, "Agora: unknown vote params");

        if (startTime == 0) startTime = uint64(block.timestamp);
        require(
            startTime >= block.timestamp, "Agora: wrong starting time"
        );

        proposals[bytes32(bytes.concat(slot, proposalId))] = Proposal(
            slot,
            proposalId,
            startTime,
            startTime + vote.votingPeriod,
            0,
            ProposalStatus.EXISTS,
            vote,
            initiater
        );

        emit ProposalSubmitted(slot, initiater, voteId, proposalId);
    }

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        uint64 votingPeriod,
        uint64 gracePeriod,
        uint64 threshold,
        bool adminValidation
    ) external onlyAdapter(Slot.VOTING) {
        VoteParam memory vote = voteParams[voteId];

        // delete vote params
        if (consensus == Consensus.NO_VOTE) {
            // check vote params utilisation
            delete voteParams[voteId];
        } else {
            require(
                vote.consensus != Consensus.NO_VOTE,
                "Agora: cannot replace voteId"
            );
        }
    }

    function _addVoteParam(
        bytes4 voteId,
        Consensus consensus,
        uint64 votingPeriod,
        uint64 gracePeriod,
        uint64 threshold,
        bool adminValidation
    ) internal {
        VoteParam memory vote = voteParams[voteId];
        require(
            vote.consensus == Consensus.NO_VOTE,
            "Agora: cannot replace params"
        );
        require(votingPeriod > 0, "Agora: below min period");
        require(
            threshold <= 10000,
            "Agora: wrong threshold or below min value"
        );

        vote.consensus = consensus;
        vote.votingPeriod = votingPeriod;
        vote.gracePeriod = gracePeriod;
        vote.threshold = threshold;
        vote.adminValidation = adminValidation;

        emit VoteParamsChanged(voteId, consensus, true);
    }

    function _removeVoteParam() internal {
        // check use !
    }
}
