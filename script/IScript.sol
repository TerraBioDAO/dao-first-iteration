// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/**
 * @notice Used to read, write and maintain a JSON file for
 * the deployment and initial setup
 */
interface IScript {
    /// @notice stored in alphabetical order
    struct Network {
        address[] admins;
        address deployer;
        address[] members;
        string name;
        address tokenTBIO;
    }

    struct InitialSetup {
        Network[] networks;
    }
}
