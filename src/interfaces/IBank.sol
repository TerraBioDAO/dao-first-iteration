// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IBank {
    event NewCommitment(
        bytes32 indexed proposalId,
        address indexed account,
        uint256 indexed lockPeriod,
        uint256 lockedAmount
    );
    event Deposit(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    event VaultCreated(bytes4 indexed vaultId);

    event VaultTransfer(
        bytes4 indexed vaultId,
        address indexed tokenAddr,
        address from,
        address to,
        uint128 amount
    );

    event VaultAmountCommitted(bytes4 indexed vaultId, address indexed tokenAddr, uint128 amount);

    struct Account {
        uint128 availableBalance;
        uint96 lockedBalance; // until 100_000 proposals
        uint32 nextRetrieval;
    }

    /**
     * @notice Max amount locked per proposal is 50_000
     * With a x50 multiplier the voteWeight is at 2.5**24
     * Which is less than 2**96 (uint96)
     * lockPeriod and retrievalDate can be stored in uint32
     * the retrieval date would overflow if it is set to 82 years
     */
    struct Commitment {
        uint96 lockedAmount;
        uint96 voteWeight;
        uint32 lockPeriod;
        uint32 retrievalDate;
    }

    struct Balance {
        uint128 availableBalance;
        uint128 commitedBalance;
    }

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
