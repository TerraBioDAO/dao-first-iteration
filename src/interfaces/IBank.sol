// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IBank {
    function newCommitment(
        address user,
        bytes32 proposalId,
        uint96 lockedAmount,
        uint32 lockPeriod,
        uint96 advanceDeposit
    ) external returns (uint96 voteWeight);

    function advancedDeposit(address user, uint128 amount) external;

    function withdrawAmount(address user, uint128 amount) external;

    function vaultCommit(
        bytes4 vaultId,
        address tokenAddr,
        uint128 amount
    ) external;

    function vaultTransfer(
        bytes4 vaultId,
        address tokenAddr,
        address destinationAddr,
        uint128 amount
    ) external returns (bool);

    function createVault(bytes4 vaultId, address[] memory tokenList) external;

    function terraBioToken() external returns (address);
}
