// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

contract logs is Script, Test {
    using stdJson for string;

    function run() public {
        emit log_string("Hello Dao builder!");
        // logs something here
    }
}
