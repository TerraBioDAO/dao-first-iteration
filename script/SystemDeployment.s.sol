// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./IScript.sol";

contract SystemDeployment is Script, IScript, Test {
    // networks in initialSetup.json
    uint8 internal LOCAL;
    uint8 internal ANVIL = 1;
    uint8 internal SEPOLIA = 2;

    // contracts

    function run() public {
        // import initial setup
        string memory file = vm.readFile("test/deployUtils.json");
        InitialSetup memory setup = abi.decode(vm.parseJson(file), (InitialSetup));
        Network memory network = setup.networks[ANVIL]; // ==> Choose network here <==

        // import env variable
        uint256 pk = vm.envUint("DEPLOYER_ANVIL");

        // start broadcast
        vm.startBroadcast(pk);
        emit log_named_address("Start deploying with", vm.addr(pk));
        emit log_named_string("On network", network.name);
        delete pk;
    }

    function _0_deployOrBindTBIOToken(address tokenAddr) internal {
        if (tokenAddr == address(0)) {
            // deploy
        }
    }
}
