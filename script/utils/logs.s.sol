// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/utils/Strings.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract logs is Script, Test {
    function run() public {
        string memory network = "goerli";
        emit log_string(vm.rpcUrl(network));

        string memory line = vm.readLine("./.deployed");
        emit log_string(line);
        line = vm.readLine("./.deployed");
        emit log_string(line);
        line = vm.readLine("./.deployed");
        emit log_string(line);
        line = vm.readLine("./.deployed");
        emit log_string(line);
        emit log_string(string(line[2:5]));
    }
}
