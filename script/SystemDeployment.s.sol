// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/utils/Strings.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "src/core/DaoCore.sol";
import "src/extensions/Agora.sol";
import "src/extensions/Bank.sol";
import "src/adapters/Financing.sol";
import "src/adapters/Onboarding.sol";
import "src/adapters/Managing.sol";
import "src/adapters/Voting.sol";

import "test/MockERC20.sol";

import "./IScript.sol";

contract SystemDeployment is Script, IScript, Test {
    using Strings for address;

    // networks in initialSetup.json
    uint8 internal LOCAL;
    uint8 internal ANVIL = 1;
    uint8 internal GOERLI = 2;
    uint8 internal SEPOLIA = 3;

    // network chocie here

    // contracts
    IERC20 internal tbio;
    DaoCore internal dao;
    Bank internal bank;
    Agora internal agora;
    Managing internal managing;
    Onboarding internal onboarding;
    Voting internal voting;
    Financing internal financing;

    // users
    address internal DEPLOYER;
    address[] internal ADMINS;
    address[] internal MEMBERS;

    function run() public {
        // import initial setup
        string memory file = vm.readFile("test/deployUtils.json");
        InitialSetup memory setup = abi.decode(vm.parseJson(file), (InitialSetup));
        Network memory network = setup.networks[ANVIL]; // ==> Choose network here <==

        // only network in cli?

        // import and save env variable
        uint256 pk = vm.envUint("DEPLOYER_GOERLI");
        DEPLOYER = vm.addr(pk);

        // start broadcast
        vm.startBroadcast(pk);
        emit log_named_address("Start deploying with", DEPLOYER);
        emit log_named_uint("Balance", DEPLOYER.balance);
        emit log_named_string("On network", network.name);
        delete pk;

        // start deployment
        _0_deployOrAttachTBIOToken(network.tokenTBIO);
        _1_deployDaoCore();
        _2_deployExtensions(true, true);
        _3_deployAdapters();
        _4_branchAdpaters();

        // end broadcast
        vm.stopBroadcast();

        // store contracts address in `.deployed` => facilitate use with `cast`
        vm.removeFile("./.deployed");
        vm.writeLine("./.deployed", string.concat("DAO=", address(dao).toHexString()));
        vm.writeLine("./.deployed", string.concat("TOKEN=", address(tbio).toHexString()));
        vm.writeLine("./.deployed", string.concat("BANK=", address(bank).toHexString()));
        vm.writeLine("./.deployed", string.concat("AGORA=", address(agora).toHexString()));
        vm.writeLine("./.deployed", string.concat("MANAGING=", address(managing).toHexString()));
        vm.writeLine(
            "./.deployed",
            string.concat("ONBOARDING=", address(onboarding).toHexString())
        );
        vm.writeLine("./.deployed", string.concat("VOTING=", address(voting).toHexString()));
        vm.writeLine("./.deployed", string.concat("FINANCING=", address(financing).toHexString()));
    }

    function _0_deployOrAttachTBIOToken(address tokenAddr) internal {
        if (tokenAddr == address(0)) {
            tokenAddr = address(new MockERC20());
        }
        tbio = IERC20(tokenAddr);
    }

    function _1_deployDaoCore() internal {
        dao = new DaoCore(DEPLOYER);
    }

    function _2_deployExtensions(bool bank_, bool agora_) internal {
        if (bank_) {
            bank = new Bank(address(dao), address(tbio));
        }
        if (agora_) {
            agora = new Agora(address(dao));
        }
    }

    function _3_deployAdapters() internal {
        managing = new Managing(address(dao));
        onboarding = new Onboarding(address(dao));
        voting = new Voting(address(dao));
        financing = new Financing(address(dao));
    }

    function _4_branchAdpaters() internal {
        dao.changeSlotEntry(Slot.ONBOARDING, address(onboarding));
        // dao.changeSlotEntry(Slot.ONBOARDING, address(onboarding));
    }
}
