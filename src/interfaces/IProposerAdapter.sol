// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IProposerAdapter {
    function finalizeProposal(bytes32 proposalId) external;

    function deleteArchive(bytes32 proposalId) external;

    function pauseToggleAdapter() external;

    function desactive() external;

    function ongoingProposals() external view returns (uint256);

    function archivedProposals() external view returns (uint256);
}
