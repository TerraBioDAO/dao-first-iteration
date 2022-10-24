// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "src/interfaces/IAgora.sol";

contract Agora_reverts is IAgora {
    function submitProposal(
        bytes4 slot,
        bytes28 proposalId,
        bool adminValidation,
        bool executable,
        bytes4 voteId,
        uint32 startTime,
        address initiater
    ) external pure {
        slot == slot;
        proposalId == proposalId;
        adminValidation == adminValidation;
        executable == executable;
        voteId == voteId;
        startTime == startTime;
        initiater == initiater;

        revert();
    }

    function changeVoteParams(
        bytes4 voteId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external pure {
        voteId == voteId;
        consensus == consensus;
        votingPeriod == votingPeriod;
        gracePeriod == gracePeriod;
        threshold == threshold;
        adminValidationPeriod == adminValidationPeriod;

        revert();
    }

    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external pure {
        proposalId == proposalId;
        voter == voter;
        voteWeight == voteWeight;
        value == value;

        revert();
    }

    function finalizeProposal(bytes32 proposalId, address finalizer) external pure {
        proposalId == proposalId;
        finalizer == finalizer;

        revert();
    }

    // GETTERS
    function getProposal(bytes32 proposalId) external pure returns (IAgora.Proposal memory) {
        proposalId == proposalId;

        revert();
    }

    function getVoteParams(bytes4 voteId) external pure returns (IAgora.VoteParam memory) {
        voteId == voteId;

        revert();
    }
}
