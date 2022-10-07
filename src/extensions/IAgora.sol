// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IAgora {
    function submitVote(
        bytes32 proposalId,
        address voter,
        uint256 voteWeight,
        uint256 value
    ) external;
}
