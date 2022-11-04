// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

/**
 * @dev Constants used in the DAO
 */
contract Constants {
    // CREDIT
    bytes4 internal constant CREDIT_VOTE = bytes4(keccak256("credit-vote"));

    // VAULTS
    bytes4 internal constant TREASURY = bytes4(keccak256("treasury"));

    // VOTE PARAMS
    bytes4 internal constant VOTE_STANDARD = bytes4(keccak256("vote-standard"));

    /**
     * @dev Collection of roles available for DAO users
     */
    bytes4 internal constant ROLE_MEMBER = bytes4(keccak256("role-member"));
    bytes4 internal constant ROLE_PROPOSER = bytes4(keccak256("role-proposer"));
    bytes4 internal constant ROLE_ADMIN = bytes4(keccak256("role-admin"));
}
