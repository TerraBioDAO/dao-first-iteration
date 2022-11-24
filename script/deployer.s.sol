// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./utils/DaoRecorder.s.sol";

contract deployer is Script, DaoRecorder, Test {
    // manage network => in Recorder
    string internal networkAlias;

    function run() public {
        // init path record and set alias network name
        networkAlias = initPath();

        // import `.env` private key
        uint256 pk = vm.envUint(string.concat("DEPLOYER_", networkAlias));
        DEPLOYER = vm.addr(pk);

        // logs info
        emit log_named_string("On network", string.concat(networkAlias));
        emit log_named_uint("Chain Id", block.chainid);
        emit log_named_uint("Block number", block.number);
        emit log_named_address("Start deploying with", DEPLOYER);
        emit log_named_uint("Balance", DEPLOYER.balance);

        // start deploying
        vm.startBroadcast(pk);
        delete pk;

        _0_deployTBIO();
        _1_deployDaoCore(DEPLOYER);
        _2a_deployAgora();
        _2b_deployBank();
        _3a_deployManaging(false);
        _3b_deployOnboarding(false);
        _3c_deployVoting(true);
        _3d_deployFinancing(true);

        // list of first members and admins
        address[] memory admins = new address[](3);
        address[] memory members = new address[](3);

        admins[0] = address(50);
        admins[1] = address(51);
        admins[2] = address(52);
        members[0] = address(53);
        members[1] = address(54);
        members[2] = address(55);

        // write record of deployed contracts
        writeRecord(networkAlias, DEPLOYER, admins, members);
    }
}
