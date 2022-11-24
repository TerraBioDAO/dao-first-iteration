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

    function _printScore(bytes32 proposalId) internal {
        IAgora.Proposal memory p = agora.getProposal(proposalId);

        uint256 totalVote = p.score.nbYes + p.score.nbNo;
        uint256 score = (p.score.nbYes * 10000) / totalVote;

        emit log_uint(p.score.nbYes);
        emit log_uint(p.score.nbNo);
        emit log_uint(p.score.nbNota);
        emit log_uint(totalVote);

        if (
            totalVote != 0 &&
            (p.score.nbYes * 10000) / totalVote >= agora.getVoteParams(p.voteParamId).threshold
        ) {
            emit log("accepted");
        } else {
            emit log("rejected");
        }

        emit log_uint(score);
        emit log("/");
        emit log_uint(agora.getVoteParams(p.voteParamId).threshold);
    }

    function _getSubmittedProposalId() internal returns (bytes32) {
        // vm.recordLogs() should be activated before the call
        Vm.Log[] memory logs = vm.getRecordedLogs();
        return bytes32(logs[0].data);
    }

    function _getScore(bytes32 proposalId) internal view returns (IAgora.Score memory) {
        return agora.getProposal(proposalId).score;
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

        // wait until end of validation period
        vm.warp(1 + agora.getVoteParams(VOTE_STANDARD).adminValidationPeriod);

        // user votes
        // YES
        vm.startPrank(USERS[2]);
        tbio.approve(BANK, 1000e18);
        voting.submitVote(proposalId, 0, 50e18, 15 days, 0);
        vm.stopPrank();

        // NO
        vm.startPrank(USERS[4]);
        tbio.approve(BANK, 1000e18);
        voting.submitVote(proposalId, 1, 25e18, 7 days, 0);
        vm.stopPrank();

        // NOTA
        vm.startPrank(USERS[0]);
        tbio.approve(BANK, 1000e18);
        voting.submitVote(proposalId, 2, 50e18, 1 days, 0);
        vm.stopPrank();

        assertEq(_getScore(proposalId).memberVoted, 3);

        // 0 ACCEPTED
        // _printScore(proposalId);
        assertEq(agora.getVoteResult(proposalId), true, "accepted");

        // Execute proposal
        vm.warp(
            1 +
                agora.getVoteParams(VOTE_STANDARD).adminValidationPeriod +
                agora.getVoteParams(VOTE_STANDARD).votingPeriod +
                agora.getVoteParams(VOTE_STANDARD).gracePeriod
        );

        // CAUTION: the counter for proposal is on the adapter but finalize decrement the Voting one
        // test with others adapters

        assertEq(voting.ongoingProposals(), 1);
        vm.prank(USERS[6]);
        voting.finalizeProposal(proposalId);
        assertEq(voting.ongoingProposals(), 0);

        assertEq(uint256(agora.getProposalStatus(proposalId)), 7);
        assertTrue(agora.getVoteParams(bytes4(keccak256("user2-vote"))).votingPeriod > 0);
    }
}
