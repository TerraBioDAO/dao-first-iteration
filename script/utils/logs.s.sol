// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/utils/Strings.sol";

import "solidity-stringutils/strings.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

contract logs is Script, Test {
    using stdJson for string;
    using Strings for address;
    using strings for *;

    strings.slice internal separator = "=".toSlice();

    function run() public {
        // logs somethings
        string memory network = "goerli";
        emit log_string(vm.rpcUrl(network));

        // read file
        string memory line = vm.readLine("./.deployed");
        emit log_string(line);
        line = vm.readLine("./.deployed");
        emit log_string(line);

        // extract part of the line
        // key
        strings.slice memory key;
        line.toSlice().split("=".toSlice(), key);
        emit log_string(key.toString());
        // => address cannot be converted into address() as it's a string

        address deployer = address(501);
        string memory json = "obj";
        json.serialize("deployer", deployer);
        json.write("./scripts/utils/output.json");
        Seriali
    }
}
