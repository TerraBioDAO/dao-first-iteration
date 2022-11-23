// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

contract logs is Script, Test {
    using stdJson for string;

    function run() public {
        // address deployer = address(501);
        // string memory json = "obj";
        // json = json.serialize("deployer", deployer);
        // json.write("./script/utils/output.json");
    }
}
