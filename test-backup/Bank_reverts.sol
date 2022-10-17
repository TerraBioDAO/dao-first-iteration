// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "src/extensions/IBank.sol";

contract Bank_reverts is IBank {
    function newCommitment(
        bytes32 proposalId,
        address voter,
        uint256 deposit,
        uint256 lockPeriod
    ) external returns (uint256 voteWeight) {
        proposalId == proposalId;
        voter == voter;
        deposit == deposit;
        lockPeriod == lockPeriod;
        revert();
    }

    function setFinancingProposalData(bytes32 proposalId, uint256 amount) external {
        proposalId == proposalId;
        amount == amount;
        revert();
    }

    function executeFinancingProposal(
        bytes32 proposalId,
        address applicant,
        uint256 amount
    ) external returns (bool) {
        proposalId == proposalId;
        applicant == applicant;
        amount == amount;

        revert();
    }
}