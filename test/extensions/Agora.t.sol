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
    address public ADAPTER_ADDR;
    address public constant USER = address(5);
    bytes4 public constant ADAPTER_SLOT = bytes4("a");
    bytes4 public constant VOTE_STANDARD = bytes4(keccak256("standard"));
    bytes4 public constant VOTE_DEFAULT = bytes4(0);

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        VOTING = _branchMock(Slot.VOTING, false);
        vm.prank(VOTING);
        agora.changeVoteParams(VOTE_DEFAULT, IAgora.Consensus(1), 86400, 86400, 8000, 86400);
        ADAPTER_ADDR = _branchMock(ADAPTER_SLOT, false);
    }

    /*////////////////////////////////
                UTILS
    ////////////////////////////////*/
    function _addVoteId(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) internal {
        vm.assume(
            (consensus == 1 || consensus == 2) &&
                threshold <= 10000 &&
                votingPeriod > 0 &&
                voteId != bytes4(0) &&
                voteId != Slot.VOTE_STANDARD
        );
        vm.prank(VOTING);
        agora.changeVoteParams(
            voteId,
            IAgora.Consensus(consensus),
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
    }

    function _submitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproval,
        bool executable,
        uint32 minStartTime,
        bytes4 voteId,
        address initiater
    ) internal returns (bytes32) {
        vm.assume(!_slotValid(slot) || slot == ADAPTER_SLOT);
        address adapter = _branchMock(slot, false);
        vm.prank(adapter);
        agora.submitProposal(
            slot,
            adapterProposalId,
            adminApproval,
            executable,
            voteId,
            minStartTime,
            initiater
        );

        return bytes32(bytes.concat(slot, adapterProposalId));
    }

    function _defaultVote() internal view returns (IAgora.VoteParam memory) {
        return agora.getVoteParams(VOTE_DEFAULT);
    }

    function _standardVote() internal view returns (IAgora.VoteParam memory) {
        return agora.getVoteParams(Slot.VOTE_STANDARD);
    }

    function _score(bytes32 ppsId) internal view returns (IAgora.Score memory) {
        return agora.getProposal(ppsId).score;
    }

    /*////////////////////////////////
            changeVoteParams()
    ////////////////////////////////*/
    function testVoteParamsAddedAtDeployment() public {
        IAgora.VoteParam memory storedParam = agora.getVoteParams(Slot.VOTE_STANDARD);
        assertEq(uint256(storedParam.consensus), uint256(1)); // TOKEN
        assertEq(storedParam.votingPeriod, 7 * Slot.DAY);
        assertEq(storedParam.gracePeriod, 3 * Slot.DAY);
        assertEq(storedParam.threshold, 8000);
        assertEq(storedParam.adminValidationPeriod, 7 * Slot.DAY);
        assertEq(storedParam.utilisation, 0);
    }

    function testAddVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        _addVoteId(voteId, consensus, votingPeriod, gracePeriod, threshold, adminValidationPeriod);

        IAgora.VoteParam memory param = IAgora.VoteParam(
            IAgora.Consensus(consensus),
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod,
            0
        );

        IAgora.VoteParam memory storedParam = agora.getVoteParams(voteId);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.adminValidationPeriod, param.adminValidationPeriod);
        assertEq(storedParam.utilisation, param.utilisation);
    }

    function testCannotAddNewVoteParam() public {
        vm.expectRevert("Cores: not the right adapter");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 50, 50, 7500, 777);

        vm.startPrank(VOTING);
        vm.expectRevert("Agora: wrong threshold or below min value");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 50, 50, 750000, 777);

        vm.expectRevert("Agora: below min period");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 0, 50, 7500, 777);

        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 50, 50, 7500, 777);
        vm.expectRevert("Agora: cannot replace params");
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 100, 100, 10000, 777);
    }

    event VoteParamsChanged(bytes4 indexed voteId, bool indexed added);

    function testEmitOnVoteParam(bytes4 voteId) public {
        vm.assume(voteId != bytes4(0));
        vm.expectEmit(true, true, false, false, address(agora));
        emit VoteParamsChanged(voteId, true);
        _addVoteId(voteId, 2, 50, 50, 7500, 777);
        // agora.changeVoteParams(voteId, IAgora.Consensus.MEMBER, 50, 50, 7500);

        emit log_bytes32(bytes32(Slot.VOTE_STANDARD));
        // 0x54fd88eb
    }

    function testRemoveVoteParam() public {
        // wait for the utilisation case
        // when a vote/ proposal is started
    }

    /*////////////////////////////////
            submitProposal()
    ////////////////////////////////*/
    function testSubmitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproved,
        bool executable,
        uint32 minStartTime
    ) public {
        vm.warp(1000);
        vm.assume(minStartTime >= 1000);
        bytes32 proposalId = _submitProposal(
            slot,
            adapterProposalId,
            adminApproved,
            executable,
            minStartTime,
            Slot.VOTE_STANDARD,
            USER
        );

        assertTrue(agora.getProposal(proposalId).active, "active");
        assertEq(agora.getProposal(proposalId).adminApproved, adminApproved, "approval");
        assertEq(agora.getProposal(proposalId).executable, executable, "executable");
        assertEq(agora.getProposal(proposalId).minStartTime, minStartTime, "min start time");
        assertEq(agora.getProposal(proposalId).initiater, USER, "initiater");

        assertEq(agora.getVoteParams(Slot.VOTE_STANDARD).utilisation, 1);
    }

    function testCannotSubmitProposal() public {
        vm.warp(1000);
        vm.startPrank(ADAPTER_ADDR);
        vm.expectRevert("Agora: unknown vote params");
        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, true, VOTE_STANDARD, 500, USER);

        vm.expectRevert("Agora: wrong starting time");
        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, true, VOTE_DEFAULT, 500, USER);

        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, true, VOTE_DEFAULT, 0, USER);

        vm.expectRevert("Agora: proposal already exist");
        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, true, VOTE_DEFAULT, 0, USER);
    }

    /*////////////////////////////////
            getProposalStatus()
    ////////////////////////////////*/
    function testGetProposalStatus() public {
        assertEq(uint8(agora.getProposalStatus(bytes32("1"))), 0);

        vm.warp(1000);

        bytes32 ppsId = _submitProposal(
            ADAPTER_SLOT,
            bytes28("1"),
            false,
            true,
            type(uint32).max,
            Slot.VOTE_STANDARD,
            USER
        );
        assertEq(uint8(agora.getProposalStatus(ppsId)), 1); // validation
        vm.warp(1000 + 7 * DAY + 100); // after validation period
        assertEq(uint8(agora.getProposalStatus(ppsId)), 2); // standby

        vm.warp(1000);
        ppsId = _submitProposal(
            ADAPTER_SLOT,
            bytes28("2"),
            true,
            false,
            2000,
            Slot.VOTE_STANDARD,
            USER
        );
        assertEq(uint8(agora.getProposalStatus(ppsId)), 2); // standby
        vm.warp(3000);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 3); // ongoing
        vm.warp(3200 + _standardVote().votingPeriod);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 4); // closed
        vm.warp(3200 + _standardVote().votingPeriod + _standardVote().gracePeriod);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 6); // to_finalize

        vm.prank(VOTING);
        agora.finalizeProposal(ppsId, USER);
        assertEq(uint8(agora.getProposalStatus(ppsId)), 7); // archived
    }

    /*////////////////////////////////
              submitVote()
    ////////////////////////////////*/
    function testSubmitVote(uint8 value, uint128 voteWeight) public {
        vm.assume(value <= 2 && voteWeight > 0 && voteWeight <= 50 * 50_000e18);
        vm.warp(1000);
        bytes32 ppsId = _submitProposal(
            ADAPTER_SLOT,
            bytes28("1"),
            true,
            true,
            0,
            Slot.VOTE_STANDARD,
            USER
        );

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
}
