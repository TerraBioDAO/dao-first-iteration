// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

//import "openzeppelin-contracts/utils/Counters.sol";
import "test/base/BaseDaoTest.sol";
import "src/adapters/Voting.sol";
import "src/extensions/Agora.sol";
import "src/extensions/Bank.sol";

contract Voting_test is BaseDaoTest {
    Agora internal agora;
    Bank internal bank;
    Voting internal voting;

    address internal AGORA;
    address internal VOTING;
    address internal BANK;

    bytes4 internal constant VOTE_ID = bytes4(keccak256("standard"));

    function setUp() public {
        _deployDao(address(501));
        _deployTBIO();
        agora = new Agora(DAO);
        bank = new Bank(DAO, TBIO);
        voting = new Voting(DAO);

        AGORA = address(agora);
        BANK = address(bank);
        VOTING = address(voting);

        _branch(Slot.AGORA, AGORA);
        _branch(Slot.BANK, BANK);
        _branch(Slot.VOTING, VOTING);
        _branchMock(Slot.ONBOARDING, false);

        _newUsersSet(5, 10);
        _mintTBIOForAll(2000e18);
        _setAsMembers();
    }

    /*////////////////////////////////
                UTILS
    ////////////////////////////////*/
    function _beforeTransfer(address user, uint256 amount) internal {
        vm.assume(amount > 0 && amount <= 2000e18);
        vm.prank(user);
        tbio.approve(BANK, amount);
    }

    function _advanceDeposit(address user, uint256 amount) internal {
        _beforeTransfer(user, amount);
        vm.prank(user);
        voting.advanceDeposit(uint128(amount));
    }

    /*////////////////////////////////
            advanceDeposit()
    ////////////////////////////////*/
    function testAdvanceDeposit(uint128 amount) public {
        _advanceDeposit(USERS[0], amount);

        assertEq(tbio.balanceOf(USERS[0]), 2000e18 - amount);
        assertEq(tbio.balanceOf(BANK), amount);

        (uint128 availableBalance, ) = bank.getBalances(USERS[0]);
        assertEq(availableBalance, uint128(amount));
    }

    /*////////////////////////////////
            withdrawAmount()
    ////////////////////////////////*/
    function testWithdrawAmount(uint128 amount) public {
        _advanceDeposit(USERS[0], amount);
        assertEq(tbio.balanceOf(USERS[0]), 2000e18 - amount);
        assertEq(tbio.balanceOf(BANK), amount);
        (uint128 availableBalance, ) = bank.getBalances(USERS[0]);
        assertEq(availableBalance, uint128(amount));

        vm.prank(USERS[0]);
        voting.withdrawAmount(amount);
        assertEq(tbio.balanceOf(USERS[0]), 2000e18);
        assertEq(tbio.balanceOf(BANK), 0);
        (availableBalance, ) = bank.getBalances(USERS[0]);
        assertEq(availableBalance, 0);
    }

    /*////////////////////////////////
            addNewVoteParam()
    ////////////////////////////////*/
    function testAddNewVoteParams(
        uint8 consensusNb,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        vm.assume((consensusNb == 1 || consensusNb == 2) && votingPeriod > 0 && threshold < 10000);
        IAgora.Consensus consensus = IAgora.Consensus(consensusNb);
        vm.prank(ADMIN);
        voting.addNewVoteParams(
            "vote-custom",
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );

        IAgora.VoteParam memory param = IAgora.VoteParam(
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod,
            0
        );

        IAgora.VoteParam memory storedParam = agora.getVoteParams(bytes4(keccak256("vote-custom")));

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.adminValidationPeriod, param.adminValidationPeriod);
        assertEq(storedParam.utilisation, param.utilisation);
    }

    function testRemoveVoteParams() public {
        IAgora.VoteParam memory voteStandard = agora.getVoteParams(Slot.VOTE_STANDARD);
        assertTrue(voteStandard.votingPeriod > 0);
        assertTrue(voteStandard.gracePeriod > 0);
        assertTrue(voteStandard.threshold > 0);
        assertTrue(voteStandard.adminValidationPeriod > 0);
        assertTrue(uint256(voteStandard.consensus) > 0);

        vm.startPrank(ADMIN);
        voting.removeVoteParams(Slot.VOTE_STANDARD);

        voteStandard = agora.getVoteParams(Slot.VOTE_STANDARD);
        assertFalse(voteStandard.votingPeriod > 0);
        assertFalse(voteStandard.gracePeriod > 0);
        assertFalse(voteStandard.threshold > 0);
        assertFalse(voteStandard.adminValidationPeriod > 0);
        assertFalse(uint256(voteStandard.consensus) > 0);
    }
}

// "addNewVoteParams(string,uint8,uint32,uint32,uint32,uint32)": "bb4fba3b",
// "advanceDeposit(uint128)": "df8b92ca",
// "eraseAdapter()": "1a71bce9",
// "executeProposal(bytes32)": "980ff6c6",
// "finalizeProposal(bytes32)": "47d0da14",
// "getConsultation(bytes28)": "e8e01b61",
// "getProposedVoteParam(bytes28)": "8f60dfd3",
// "isExtension()": "a1a0bdec",
// "ongoingProposals()": "fd2b5e9d",
// "pauseAdapter()": "074568e9",
// "proposeConsultation(string,string,uint32)": "26827a93",
// "proposeNewVoteParams(string,uint8,uint32,uint32,uint32,uint32,uint32)": "59e4cd85",
// "removeVoteParams(bytes4)": "ca10143d",
// "slotId()": "cecc2c6d",
// "submitVote(bytes32,uint256,uint96,uint32,uint96)": "72d26234",
// "withdrawAmount(uint128)": "ef5e218a"
