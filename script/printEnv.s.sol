// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "openzeppelin-contracts/utils/Strings.sol";

import "./utils/DaoRecorder.s.sol";
import "forge-std/Test.sol";

contract printEnv is DaoRecorder, Test {
    using Strings for address;

    function run() public {
        string memory networkAlias = initPath();
        string memory envPath = string.concat("./.", networkAlias);
        vm.writeFile(envPath, "# Environment file created by `printEnv`");
        vm.writeLine(envPath, " \n");

        Contracts memory c = abi.decode(readRecordKey(".contracts"), (Contracts));

        // contract address
        vm.writeLine(envPath, string.concat("DAO=", c.daoCore.toHexString()));
        vm.writeLine(envPath, string.concat("TOKEN=", c.tbio.toHexString()));
        vm.writeLine(envPath, string.concat("BANK=", c.bank.toHexString()));
        vm.writeLine(envPath, string.concat("AGORA=", c.agora.toHexString()));
        vm.writeLine(envPath, string.concat("MANAGING=", c.managing.toHexString()));
        vm.writeLine(envPath, string.concat("ONBOARDING=", c.onboarding.toHexString()));
        vm.writeLine(envPath, string.concat("VOTING=", c.voting.toHexString()));
        vm.writeLine(envPath, string.concat("FINANCING=", c.financing.toHexString()));
    }
}
