// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "src/core/DaoCore.sol";

contract Deployment_test is Test {
    // address
    address[] internal ADMINS;
    address[] internal MEMBERS;

    // contracts
    DaoCore internal dao;
    address internal DAO;

    function setUp() public {
        // network config
        // 0. LOCAL
        // 1. ANVIL
        // 2. SEPOLIA
        // address input
    }

    function testDeployment() public {
        string memory path = "output.txt";

        // string memory line1 = "first line2";
        // vm.writeLine(path, line1); =append
        // emit log_string(vm.readFile(path));

        emit log_address(address(501));
        emit log_address(address(502));
        emit log_address(address(0));
        emit log_address(address(1));
        emit log_address(address(2));
        emit log_address(address(3));
        emit log_address(address(4));
    }
}
