// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library Slot {
    // VARIABLES
    uint32 internal constant DAY = 86400;

    // GENERAL
    bytes4 internal constant EMPTY = 0x00000000;
    bytes4 internal constant CORE = 0xFFFFFFFF;

    // ADAPTERS
    bytes4 internal constant MANAGING = bytes4(keccak256("managing"));
    bytes4 internal constant ONBOARDING = bytes4(keccak256("onboarding"));
    bytes4 internal constant VOTING = bytes4(keccak256("voting"));
    bytes4 internal constant FINANCING = bytes4(keccak256("financing"));

    // EXTENSIONS
    bytes4 internal constant BANK = bytes4(keccak256("bank"));
    bytes4 internal constant AGORA = bytes4(keccak256("agora"));

    // ROLES
    bytes4 internal constant USER_EXISTS = bytes4(keccak256("user-exists"));
    bytes4 internal constant USER_PROPOSER = bytes4(keccak256("user-proposer"));
    bytes4 internal constant USER_ADMIN = bytes4(keccak256("user-admin"));

    // CREDIT
    bytes4 internal constant CREDIT_VOTE = bytes4(keccak256("credit-vote"));

    // VAULTS
    bytes4 internal constant TREASURY = bytes4(keccak256("treasury"));

    // VOTE PARAMS
    bytes4 internal constant VOTE_STANDARD = bytes4(keccak256("vote-standard"));
}
