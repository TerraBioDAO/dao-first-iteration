// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IAgora {
    event VoteParamsChanged(bytes4 indexed voteParamId, bool indexed added); // add consensus?

    event ProposalSubmitted(
        bytes4 indexed slot,
        address indexed from,
        bytes4 indexed voteParam,
        bytes32 proposalId
    );

    event ProposalFinalized(
        bytes32 indexed proposalId,
        address indexed finalizer,
        bool indexed accepted
    );

    event MemberVoted(
        bytes32 indexed proposalId,
        address indexed voter,
        uint256 indexed value,
        uint256 voteWeight
    );
    enum ProposalStatus {
        UNKNOWN,
        VALIDATION,
        STANDBY,
        ONGOING,
        CLOSED,
        SUSPENDED,
        TO_FINALIZE,
        ARCHIVED // until last lock period
    }

    enum Consensus {
        UNINITIATED,
        TOKEN, // take vote weight
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
        uint32 threshold; // 0 to 10000
        uint32 adminValidationPeriod;
        uint256 usesCount; // to fit
    }

    struct Proposal {
        bool active;
        bool adminApproved;
        bool suspended;
        bool proceeded; // ended or executed
        uint32 createdAt;
        uint32 minStartTime;
        uint32 shiftedTime;
        uint32 suspendedAt;
        bytes4 voteParamId;
        address initiater;
        Score score;
    }

    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bool adminValidation,
        bytes4 voteParamId,
        uint32 startTime,
        address initiater
    ) external;

    function changeVoteParam(
        bool isToAdd,
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external;

    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external;

    function finalizeProposal(
        bytes32 proposalId,
        address finalizer,
        bool accepted
    ) external;

    function deleteArchive(bytes32 proposalId, address user) external;

    // GETTERS
    function getProposalStatus(bytes32 proposalId) external view returns (ProposalStatus);

    function getVoteResult(bytes32 proposalId) external view returns (bool);

    function getProposal(bytes32 proposalId) external view returns (Proposal memory);

    function getVoteParams(bytes4 voteParamId) external view returns (VoteParam memory);
}
