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
        assertEq(storedParam.usesCount, param.usesCount);
    }

    function testRemoveVoteParams() public {
        IAgora.VoteParam memory voteStandard = agora.getVoteParams(VOTE_STANDARD);
        assertTrue(voteStandard.votingPeriod > 0);
        assertTrue(voteStandard.gracePeriod > 0);
        assertTrue(voteStandard.threshold > 0);
        assertTrue(voteStandard.adminValidationPeriod > 0);
        assertTrue(uint256(voteStandard.consensus) > 0);

        vm.startPrank(ADMIN);
        voting.removeVoteParams(VOTE_STANDARD);

        voteStandard = agora.getVoteParams(VOTE_STANDARD);
        assertFalse(voteStandard.votingPeriod > 0);
        assertFalse(voteStandard.gracePeriod > 0);
        assertFalse(voteStandard.threshold > 0);
        assertFalse(voteStandard.adminValidationPeriod > 0);
        assertFalse(uint256(voteStandard.consensus) > 0);
    }

    /*////////////////////////////////
            proposeNewVoteParams()
        ////////////////////////////////*/
    function testProposeNewVoteParamsZeroMinStart() public {
        vm.startPrank(USERS[0]);
        vm.warp(1641070800);

        voting.proposeNewVoteParams(
            "testNewVotePram",
            IAgora.Consensus.MEMBER,
            1 days,
            1 days,
            50000,
            0,
            7 days
        );

        bytes32 registeredProposalId = hex"0e49311667dd89a9d508d9903eaea1c84f6d29940a37d339387e29b045cf8f06";

        Voting.ProposedVoteParam memory proposedVoteParam = voting.getProposedVoteParam(
            bytes28(registeredProposalId << 32)
        );
        assertEq(proposedVoteParam.votingPeriod, 86400);
        assertEq(proposedVoteParam.gracePeriod, 86400);
        assertEq(proposedVoteParam.threshold, 50000);
        assertEq(proposedVoteParam.adminValidationPeriod, 604800);
        assertEq(uint256(proposedVoteParam.consensus), uint256(IAgora.Consensus.MEMBER));

        IAgora.VoteParam memory voteParam = agora.getVoteParams(VOTE_STANDARD_RAW_VALUE);
        assertEq(voteParam.usesCount, 1);

        IAgora.Proposal memory proposal = agora.getProposal(registeredProposalId);

        assertFalse(proposal.adminApproved);
        assertTrue(proposal.active);
        assertEq(proposal.voteParamId, VOTE_STANDARD_RAW_VALUE);
        assertEq(proposal.initiater, USERS[0]);
        assertEq(proposal.minStartTime, 1641070800);
    }

    function testProposeNewVoteParams(uint32 minStartTime) public {
        vm.assume(minStartTime > 0);
        vm.startPrank(USERS[0]);

        voting.proposeNewVoteParams(
            "testNewVoteParam",
            IAgora.Consensus.TOKEN,
            3 days,
            2 days,
            50001,
            minStartTime,
            4 days
        );

        bytes32 registeredProposalId = hex"0e493116fa7a66f7081a5170abf3fa16e897fc53a1bea03b97d248cc6af1596f";

        Voting.ProposedVoteParam memory proposedVoteParam = voting.getProposedVoteParam(
            bytes28(registeredProposalId << 32)
        );
        assertEq(proposedVoteParam.votingPeriod, 259200);
        assertEq(proposedVoteParam.gracePeriod, 172800);
        assertEq(proposedVoteParam.threshold, 50001);
        assertEq(proposedVoteParam.adminValidationPeriod, 345600);
        assertEq(uint256(proposedVoteParam.consensus), uint256(IAgora.Consensus.TOKEN));

        IAgora.VoteParam memory voteParam = agora.getVoteParams(VOTE_STANDARD_RAW_VALUE);
        assertEq(voteParam.usesCount, 1);

        IAgora.Proposal memory proposal = agora.getProposal(registeredProposalId);

        assertFalse(proposal.adminApproved);
        assertTrue(proposal.active);
        assertEq(proposal.voteParamId, VOTE_STANDARD_RAW_VALUE);
        assertEq(proposal.initiater, USERS[0]);
        assertEq(proposal.minStartTime, minStartTime);
    }

    function testProposeConsultation() public {
        vm.startPrank(USERS[0]);
        vm.warp(1641070800);

        voting.proposeConsultation("N-1","First consulation",0);

        assertEq(voting.ongoingProposals(),1);

        emit log_bytes32(bytes32(Slot.AGORA));
        emit log_bytes32(bytes32(Slot.BANK));
        emit log_bytes32(bytes32(Slot.VOTING));
        emit log_bytes32(bytes32(Slot.FINANCING));
        emit log_bytes32(bytes32(Slot.MANAGING));
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
// "removeVoteParams(bytes4)": "ca10143d",
// "slotId()": "cecc2c6d",
// "submitVote(bytes32,uint256,uint96,uint32,uint96)": "72d26234",
// "withdrawAmount(uint128)": "ef5e218a"
