// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IAgora {
    enum ProposalStatus {
        UNKNOWN,
        ONGOING,
        CLOSED,
        SUSPENDED,
        ACCEPTED,
        REJECTED,
        TO_PROCEED,
        EXECUTED
    }

    enum Consensus {
        NO_VOTE,
        TOKEN, // take vote weigth
        MEMBER // 1 address = 1 vote
    }

    struct Score {
        uint128 nbYes;
        uint128 nbNo;
        uint128 nbNota; // none of the above
        // see: https://blog.tally.xyz/understanding-governor-bravo-69b06f1875da
        uint128 memberVoted;
    }

    struct VoteParam {
        Consensus consensus;
        uint32 votingPeriod;
        uint32 gracePeriod;
        uint64 threshold;
        uint256 utilisation; // to fit
    }

    struct Proposal {
        bool active;
        bool adminValidation;
        bool executable;
        bool proceeded; // ended or executed
        uint32 startTime;
        uint32 endTime;
        address initiater;
        Score score;
        VoteParam params;
    }

    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bool adminValidation,
        bool executable,
        bytes4 voteId,
        uint32 startTime,
        address initiater
    ) external;

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint64 threshold
    ) external;

    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external;

    function processProposal(bytes4 slot, bytes28 proposalId) external;

    // GETTERS
    function getProposal(bytes32 proposalId) external view returns (Proposal memory);

    function getVoteParams(bytes4 voteId) external view returns (VoteParam memory);
}
