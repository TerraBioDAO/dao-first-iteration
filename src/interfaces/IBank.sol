// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IBank {
    function newCommitment(
        address user,
        bytes32 proposalId,
        uint96 lockedAmount,
        uint32 lockPeriod,
        uint96 advanceDeposit
    ) external returns (uint96 voteWeight);

    function setFinancingProposalData(bytes32 proposalId, uint256 amount) external;

    function executeFinancingProposal(
        bytes32 proposalId,
        address applicant,
        uint256 amount
    ) external returns (bool);
}
