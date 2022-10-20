// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IAdapter {
    // ADD AGORA descision !
    function finalizeProposal(bytes28 proposalId) external returns (bool);
}
