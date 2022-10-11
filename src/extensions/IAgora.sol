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

    enum VoteType {
        YES_NO, // score = (uint128,uint128) = (y,n)
        PREFERENCE, // score = (uint8,uint8,uint8, ...) = (1,2,3, ...)
        PERCENTAGE // score = 0 <-> 10000 = (0% <-> 100,00%)
    }

    struct VoteParam {
        Consensus consensus;
        VoteType voteType;
        uint64 votingPeriod;
        uint64 gracePeriod;
        uint64 threshold;
        bool adminValidation;
        uint256 utilisation;
    }

    struct Proposal {
        bytes4 slot;
        bytes28 proposalId; // not useful
        bool executable;
        uint64 startTime;
        uint64 endTime;
        uint256 score; //score contenant le nombre Y et N pour un type VOTE YES NO à faire evoluer ?
        ProposalStatus status;
        VoteParam params;
        address initiater;
    }

    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bool executable,
        bytes4 voteId,
        uint64 startTime,
        address initiater
    ) external;

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        VoteType voteType,
        uint64 votingPeriod,
        uint64 gracePeriod,
        uint64 threshold,
        bool adminValidation
    ) external;

    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external;

    function processProposal(bytes4 slot, bytes28 proposalId) external;

    function changeProposalStatus(bytes32 proposalId, ProposalStatus newStatus) external;

    // GETTERS
    function getProposal(bytes32 proposalId) external view returns (Proposal memory);

    function getVoteParams(bytes4 voteId) external view returns (VoteParam memory);
}
