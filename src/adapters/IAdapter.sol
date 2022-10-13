// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IAdapter {
    function processProposal(bytes32 proposalId) external returns (bool);
}
