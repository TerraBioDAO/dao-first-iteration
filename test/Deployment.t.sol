// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import "src/core/DaoCore.sol";
import "src/extensions/Agora.sol";
import "src/extensions/Bank.sol";
import "src/adapters/Financing.sol";
import "src/adapters/Onboarding.sol";
import "src/adapters/Managing.sol";
import "src/adapters/Voting.sol";

import "./MockERC20.sol";

contract Deployment_test is Test {
    using stdJson for string;

    // json file
    struct Network {
        address[] admins;
        address deployer;
        address[] members;
        string name;
        address tokenTBIO;
    }
    struct Json {
        Network[] networks;
    }

    // address
    address[] internal ADMINS;
    address internal DEPLOYER;
    address[] internal MEMBERS;
    address internal TBIO;

    // contracts
    DaoCore internal dao;
    address internal DAO;

    Agora internal agora;
    address internal AGORA;

    Bank internal bank;
    address internal BANK;

    Voting internal voting;
    address internal VOTING;

    Financing internal financing;
    address internal FINANCING;

    Managing internal managing;
    address internal MANAGING;

    Onboarding internal onboarding;
    address internal ONBOARDING;

    MockERC20 internal tbio;

    string internal _deployment = "deployment";

    function setUp() public {
        // read JSON file
        string memory file = vm.readFile("test/deployUtils.json");
        Json memory json = abi.decode(vm.parseJson(file), (Json));
        Network memory network = json.networks[0]; // ==> Choose network here <==

        // fork network config
        if (keccak256(bytes(network.name)) != keccak256("local")) {
            // no fork on local
            vm.createSelectFork(network.name);
        }

        emit log_named_string("Connected on", network.name);

        // address input
        ADMINS = network.admins;
        MEMBERS = network.members;
        DEPLOYER = network.deployer;
        TBIO = network.tokenTBIO;

        // deploy TBIO if needed
        if (TBIO == address(0)) {
            vm.prank(DEPLOYER);
            tbio = new MockERC20();
            TBIO = address(tbio);
        }
    }

    function testDeployment() public {
        vm.startPrank(DEPLOYER);
        dao = new DaoCore(DEPLOYER);
        DAO = address(dao);
        agora = new Agora(DAO);
        AGORA = address(agora);
        bank = new Bank(DAO, TBIO);
        BANK = address(bank);
        voting = new Voting(DAO);
        VOTING = address(voting);
        financing = new Financing(DAO);
        FINANCING = address(financing);
        managing = new Managing(DAO);
        MANAGING = address(managing);
        onboarding = new Onboarding(DAO);
        ONBOARDING = address(onboarding);

        dao.changeSlotEntry(Slot.AGORA, AGORA);
        dao.changeSlotEntry(Slot.BANK, BANK);
        dao.changeSlotEntry(Slot.VOTING, VOTING);
        dao.changeSlotEntry(Slot.FINANCING, FINANCING);
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);
        dao.changeSlotEntry(Slot.MANAGING, MANAGING);

        // assertEq(dao.getSlotContractAddr(Slot.AGORA), AGORA, "slot agora");
        // assertEq(dao.getSlotContractAddr(Slot.BANK), BANK);
        // assertEq(dao.getSlotContractAddr(Slot.VOTING), VOTING);
        // assertEq(dao.getSlotContractAddr(Slot.FINANCING), FINANCING);
        // assertEq(dao.getSlotContractAddr(Slot.MANAGING), MANAGING);
        // assertEq(dao.getSlotContractAddr(Slot.ONBOARDING), ONBOARDING);
        emit log_uint(DEPLOYER.balance);
    }
}
