// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/interfaces/IAgora.sol";
import "src/adapters/Voting.sol";

contract Agora_test is BaseDaoTest {
    Agora public agora;

    address public AGORA;
    address public VOTING;
    address public ADAPTER;
    address public constant USER = address(5);
    bytes4 public constant SLOT = bytes4("a");
    bytes4 public constant VOTE_STANDARD = bytes4(keccak256("standard"));
    bytes4 public constant VOTE_DEFAULT = bytes4(0);
    bytes32 public constant PPS = bytes32("a");

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        VOTING = _branchMock(Slot.VOTING, false);
        vm.prank(VOTING);
        agora.changeVoteParams(VOTE_DEFAULT, IAgora.Consensus(1), 86400, 86400, 8000);
        ADAPTER = _branchMock(SLOT, false);
    }

    // changeVoteParams()
    function testAddVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold
    ) public {
        _addVoteId(voteId, consensus, votingPeriod, gracePeriod, threshold);

        IAgora.VoteParam memory param = IAgora.VoteParam(
            IAgora.Consensus(consensus),
            votingPeriod,
            gracePeriod,
            threshold,
            0
        );

        IAgora.VoteParam memory storedParam = agora.getVoteParams(voteId);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.utilisation, param.utilisation);
    }

    function testCannotAddNewVoteParam() public {
        vm.expectRevert("Cores: not the right adapter");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 50, 50, 7500);

        vm.startPrank(VOTING);
        vm.expectRevert("Agora: wrong threshold or below min value");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 50, 50, 750000);

        vm.expectRevert("Agora: below min period");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 0, 50, 7500);

        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 50, 50, 7500);
        vm.expectRevert("Agora: cannot replace params");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 100, 100, 10000);
    }

    event VoteParamsChanged(bytes4 indexed voteId, bool indexed added);

    function testEmitOnVoteParam(bytes4 voteId) public {
        vm.assume(voteId != bytes4(0));
        vm.expectEmit(true, true, false, false, address(agora));
        emit VoteParamsChanged(voteId, true);
        _addVoteId(voteId, 2, 50, 50, 7500);
        // agora.changeVoteParams(voteId, IAgora.Consensus.MEMBER, 50, 50, 7500);
    }

    function testRemoveVoteParam() public {
        // wait for the utilisation case
        // when a vote/ proposal is started
    }

    function testSubmitProposal(
        bool adminApproved,
        bool executable,
        uint32 minStartTime
    ) public {
        vm.assume(minStartTime >= 1000);
        vm.warp(1000);
        bytes32 ppsId = _submitProposal(adminApproved, executable, minStartTime, bytes28(PPS));

        assertTrue(agora.getProposal(ppsId).active, "active");
        assertEq(agora.getProposal(ppsId).adminApproved, adminApproved, "approval");
        assertEq(agora.getProposal(ppsId).executable, executable, "executable");
        assertEq(agora.getProposal(ppsId).minStartTime, minStartTime, "min start time");
        assertEq(agora.getProposal(ppsId).initiater, USER, "initiater");

        assertEq(agora.getVoteParams(VOTE_DEFAULT).utilisation, 1);
    }

    function testCannotSubmitProposal() public {
        vm.warp(1000);
        vm.prank(ADAPTER);
        vm.expectRevert("Agora: unknown vote params");
        agora.submitProposal(SLOT, bytes28(PPS), true, true, VOTE_STANDARD, 500, USER);

        vm.prank(ADAPTER);
        vm.expectRevert("Agora: wrong starting time");
        agora.submitProposal(SLOT, bytes28(PPS), true, true, VOTE_DEFAULT, 500, USER);

        vm.prank(ADAPTER);
        agora.submitProposal(SLOT, bytes28(PPS), true, true, VOTE_DEFAULT, 0, USER);

        vm.prank(ADAPTER);
        vm.expectRevert("Agora: proposal already exist");
        agora.submitProposal(SLOT, bytes28(PPS), true, true, VOTE_DEFAULT, 0, USER);
    }

    function testGetProposalStatus() public {
        /* enum ProposalStatus {0  UNKNOWN,
                                1  VALIDATION,
                                2  STANDBY,
                                3  ONGOING,
                                4  CLOSED,
                                5  SUSPENDED,
                                6  TO_FINALIZE,
                                7  ARCHIVED  }*/

        assertEq(uint8(agora.getProposalStatus(PPS)), 0);

        vm.warp(1000);
        bytes32 ppsId = _submitProposal(false, true, type(uint32).max, bytes28("1"));
        assertEq(uint8(agora.getProposalStatus(ppsId)), 1); // validation
        vm.warp(1000 + 7 * DAY + 100); // after validation period
        assertEq(uint8(agora.getProposalStatus(ppsId)), 2); // standby

        vm.warp(1000);
        ppsId = _submitProposal(true, false, 2000, bytes28("2"));
        assertEq(uint8(agora.getProposalStatus(ppsId)), 2); // standby
        vm.warp(3000);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 3); // ongoing
        vm.warp(3200 + _defaultVote().votingPeriod);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 4); // closed
        vm.warp(3200 + _defaultVote().votingPeriod + _defaultVote().gracePeriod);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 6); // to_finalize

        vm.prank(VOTING);
        agora.finalizeProposal(ppsId, USER);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 7); // archived
    }

    function testSubmitVote(uint8 value, uint128 voteWeight) public {
        vm.assume(value <= 2 && voteWeight > 0 && voteWeight <= 50 * 50_000e18);
        vm.warp(1000);
        bytes32 ppsId = _submitProposal(true, false, 0, bytes28("1"));

        vm.warp(2000);
        vm.prank(VOTING);
        agora.submitVote(ppsId, USER, voteWeight, value);

        assertTrue(agora.getVotes(ppsId, USER));
        assertEq(_score(ppsId).memberVoted, 1, "members");
        if (value == 0) {
            assertEq(_score(ppsId).nbYes, voteWeight, "yes");
        } else if (value == 1) {
            assertEq(_score(ppsId).nbNo, voteWeight, "no");
        } else {
            assertEq(_score(ppsId).nbNota, voteWeight, "nota");
        }
    }

    function testCannotSubmitVote() private {
        //
    }

    function testSubmitMemberVote() private {
        // add default member vote at `bytes4("1")`
    }

    function testGetVoteResult() private {
        // play with threshold
    }

    function testFinalizeProposal() private {
        // mock `IAdapter(adapter).finalizeProposal(bytes28(proposalId << 32));`
    }

    function testCannotFinalizeProposal() private {
        // include vote rejected
    }

    // ------------------------- UTILS
    function _addVoteId(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold
    ) internal {
        vm.assume(
            (consensus == 1 || consensus == 2) &&
                threshold <= 10000 &&
                votingPeriod > 0 &&
                voteId != bytes4(0)
        );
        vm.prank(VOTING);
        agora.changeVoteParams(
            voteId,
            IAgora.Consensus(consensus),
            votingPeriod,
            gracePeriod,
            threshold
        );
    }

    function _submitProposal(
        bool adminApproval,
        bool executable,
        uint32 minStartTime,
        bytes28 ppsId
    ) internal returns (bytes32) {
        vm.prank(ADAPTER);
        agora.submitProposal(
            SLOT,
            ppsId,
            adminApproval,
            executable,
            VOTE_DEFAULT,
            minStartTime,
            USER
        );

        return bytes32(bytes.concat(SLOT, ppsId));
    }

    function _defaultVote() internal view returns (IAgora.VoteParam memory) {
        return agora.getVoteParams(VOTE_DEFAULT);
    }

    function _score(bytes32 ppsId) internal view returns (IAgora.Score memory) {
        return agora.getProposal(ppsId).score;
    }
}
