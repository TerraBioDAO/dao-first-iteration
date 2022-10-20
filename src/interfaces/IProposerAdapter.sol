// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IProposerAdapter {
    function finalizeProposal(bytes32 proposalId) external;

    function ongoingProposals() external view returns (uint256);
}
