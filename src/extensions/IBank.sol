// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IBank {
    function newCommitment(
        bytes32 proposalId,
        address voter,
        uint256 deposit,
        uint256 lockPeriod
    ) external returns (uint256 voteWeight);

    function executeFinancingProposal(address applicant, uint256 amount) external returns (bool);
}
