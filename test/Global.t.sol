// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "test/base/BaseDaoTest.sol";
import "src/interfaces/IAgora.sol";
import "src/extensions/Agora.sol";
import "src/extensions/Bank.sol";
import "src/adapters/Financing.sol";
import "src/adapters/Onboarding.sol";
import "src/adapters/Managing.sol";
import "src/adapters/Voting.sol";

contract Global is BaseDaoTest {
    // contracts
    Agora internal agora;
    Bank internal bank;
    Financing internal financing;
    Onboarding internal onboarding;
    Managing internal managing;
    Voting internal voting;

    // address
    address internal AGORA;
    address internal BANK;
    address internal FINANCING;
    address internal ONBOARDING;
    address internal MANAGING;
    address internal VOTING;

    // users
    address internal constant ADMIN2 = address(502);

    function setUp() public {
        _deployDao(address(501));
        _deployTBIO();

        agora = new Agora(DAO);
        bank = new Bank(DAO, TBIO);
        financing = new Financing(DAO);
        onboarding = new Onboarding(DAO);
        managing = new Managing(DAO);
        voting = new Voting(DAO);

        AGORA = address(agora);
        BANK = address(bank);
        FINANCING = address(financing);
        ONBOARDING = address(onboarding);
        MANAGING = address(managing);
        VOTING = address(voting);

        vm.prank(ADMIN);
        dao.addNewAdmin(ADMIN2);

        _branch(Slot.AGORA, AGORA);
        _branch(Slot.BANK, BANK);
        _branch(Slot.FINANCING, FINANCING);
        _branch(Slot.VOTING, VOTING);
        _branch(Slot.ONBOARDING, ONBOARDING);
        _branch(Slot.MANAGING, MANAGING);

        _newUsersSet(0, 10);
        _mintTBIOForAll(1000e18);
    }

    // some new users in the DAO
    function _membersJoin() internal {
        vm.prank(USERS[0]);
        onboarding.joinDao();
        vm.prank(USERS[2]);
        onboarding.joinDao();
        vm.prank(USERS[4]);
        onboarding.joinDao();
        vm.prank(USERS[6]);
        onboarding.joinDao();
    }

    function _getSubmittedProposalId() internal returns (bytes32) {
        // vm.recordLogs() should be activated before the call
        Vm.Log[] memory logs = vm.getRecordedLogs();
        return bytes32(logs[0].data);
    }

    function testUserJoinDao() public {
        _membersJoin();
        assertTrue(dao.hasRole(USERS[0], ROLE_MEMBER));
        assertTrue(dao.hasRole(USERS[2], ROLE_MEMBER));
        assertTrue(dao.hasRole(USERS[4], ROLE_MEMBER));
        assertTrue(dao.hasRole(USERS[6], ROLE_MEMBER));
        assertEq(dao.membersCount(), 6);
    }

    // proposal life cycle
    function testProposalLifeCycle() public {
        _membersJoin();

        // users start proposal
        vm.prank(USERS[2]);

        vm.recordLogs();
        voting.proposeNewVoteParams("user2-vote", IAgora.Consensus.MEMBER, 2 days, 0, 7500, 0, 0);
        bytes32 proposalId = _getSubmittedProposalId();

        // admin cannot valid (not implemented)
        // so wait until end of validation period
        vm.warp(1 + agora.getVoteParams(VOTE_STANDARD).adminValidationPeriod);

        // users votes
        vm.startPrank(USERS[0]);
        tbio.approve(BANK, 1000e18);
        emit log_uint(agora.getProposal(proposalId).createdAt);
        emit log_uint(agora.getProposal(proposalId).shiftedTime);
        emit log_uint(uint256(agora.getProposalStatus(proposalId)));
        // AGORA seem to not postpone the voting period ! ISSUE
        voting.submitVote(proposalId, 1, 50e18, 1 days, 0);
    }
}
