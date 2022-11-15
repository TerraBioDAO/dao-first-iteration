// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/interfaces/IAgora.sol";
import "src/adapters/Voting.sol";

contract Agora_test is BaseDaoTest {
    using Slot for bytes28;

    Agora public agora;

    address public AGORA;
    address public VOTING;
    address public ADAPTER_ADDR;
    address public constant USER = address(5);
    bytes4 public constant ADAPTER_SLOT = bytes4("a");
    bytes4 public constant VOTE_MEMBER = bytes4(keccak256("member"));
    bytes4 public constant VOTE_DEFAULT = bytes4(0);

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        VOTING = _branchMock(Slot.VOTING, false);
        ADAPTER_ADDR = _branchMock(ADAPTER_SLOT, false);

        vm.startPrank(VOTING);
        agora.changeVoteParams(VOTE_DEFAULT, IAgora.Consensus(1), 86400, 86400, 8000, 86400);
        agora.changeVoteParams(VOTE_MEMBER, IAgora.Consensus(2), 86400, 86400, 8000, 86400);
        vm.stopPrank();
    }

    /*////////////////////////////////
                UTILS
    ////////////////////////////////*/
    function _prepareAddVoteParam(
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
                voteId != VOTE_STANDARD
        );
        vm.prank(VOTING);
    }

    function _addVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) internal returns (IAgora.VoteParam memory) {
        _prepareAddVoteParam(
            voteId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
        agora.changeVoteParams(
            voteId,
            IAgora.Consensus(consensus),
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
        return
            IAgora.VoteParam(
                IAgora.Consensus(consensus),
                votingPeriod,
                gracePeriod,
                threshold,
                adminValidationPeriod,
                0
            );
    }

    function _prepareSubmitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        uint32 minStartTime
    ) internal returns (bytes32 proposalId) {
        // check params
        vm.assume((minStartTime == 0 || minStartTime >= block.timestamp) && slot != Slot.EMPTY);

        // create a new adapter (branched to the DAO) if inexistant
        address adapter = dao.getSlotContractAddr(slot);
        if (adapter == address(0)) {
            adapter = _branchMock(slot, false);
        }

        proposalId = bytes32(bytes.concat(slot, adapterProposalId));
        vm.prank(adapter);
        // call submitProposal
    }

    function _submitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproval,
        uint32 minStartTime,
        bytes4 voteId,
        address initiater
    ) internal returns (bytes32 proposalId) {
        proposalId = _prepareSubmitProposal(slot, adapterProposalId, minStartTime);
        vm.assume(_isSlotActive(slot));
        // slot valid
        agora.submitProposal(
            slot,
            adapterProposalId,
            adminApproval,
            voteId,
            minStartTime,
            initiater
        );
    }

    function _defaultVote() internal view returns (IAgora.VoteParam memory) {
        return agora.getVoteParams(VOTE_DEFAULT);
    }

    function _standardVote() internal view returns (IAgora.VoteParam memory) {
        return agora.getVoteParams(VOTE_STANDARD);
    }

    function _score(bytes32 ppsId) internal view returns (IAgora.Score memory) {
        return agora.getProposal(ppsId).score;
    }

    function testVoteParamsAddedAtDeployment() public {
        IAgora.VoteParam memory storedParam = agora.getVoteParams(VOTE_STANDARD);
        assertEq(uint256(storedParam.consensus), uint256(1)); // TOKEN
        assertEq(storedParam.votingPeriod, 7 days);
        assertEq(storedParam.gracePeriod, 3 days);
        assertEq(storedParam.threshold, 8000);
        assertEq(storedParam.adminValidationPeriod, 7 days);
        assertEq(storedParam.utilisation, 0);
    }

    /*////////////////////////////////
            changeVoteParams()
    ////////////////////////////////*/
    function testAddVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        IAgora.VoteParam memory param = _addVoteParam(
            voteId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
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
        bytes4 NEW_VOTE = bytes4("5");
        vm.expectRevert("Cores: not the right adapter");
        agora.changeVoteParams(NEW_VOTE, IAgora.Consensus.MEMBER, 50, 50, 7500, 777);

        vm.startPrank(VOTING);
        vm.expectRevert("Agora: wrong threshold or below min value");
        agora.changeVoteParams(NEW_VOTE, IAgora.Consensus.MEMBER, 50, 50, 750000, 777);

        vm.expectRevert("Agora: below min period");
        agora.changeVoteParams(NEW_VOTE, IAgora.Consensus.MEMBER, 0, 50, 7500, 777);

        agora.changeVoteParams(NEW_VOTE, IAgora.Consensus.MEMBER, 50, 50, 7500, 777);
        vm.expectRevert("Agora: cannot replace params");
        agora.changeVoteParams(NEW_VOTE, IAgora.Consensus.MEMBER, 100, 100, 10000, 777);
    }

    event VoteParamsChanged(bytes4 indexed voteId, bool indexed added);

    function testEmitOnVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        _prepareAddVoteParam(
            voteId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );

        vm.expectEmit(true, true, false, false, AGORA);
        emit VoteParamsChanged(voteId, true);
        agora.changeVoteParams(
            voteId,
            IAgora.Consensus(consensus),
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
    }

    function testRemoveVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        IAgora.VoteParam memory param = _addVoteParam(
            voteId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );

        IAgora.VoteParam memory storedParam = agora.getVoteParams(voteId);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.adminValidationPeriod, param.adminValidationPeriod);
        assertEq(storedParam.utilisation, param.utilisation);

        vm.prank(VOTING);
        agora.changeVoteParams(
            voteId,
            IAgora.Consensus.NO_VOTE,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );

        storedParam = agora.getVoteParams(voteId);

        assertEq(uint256(storedParam.consensus), uint256(IAgora.Consensus.NO_VOTE));
        assertEq(storedParam.votingPeriod, 0);
        assertEq(storedParam.gracePeriod, 0);
        assertEq(storedParam.threshold, 0);
        assertEq(storedParam.adminValidationPeriod, 0);
        assertEq(storedParam.utilisation, 0);
    }

    function testCannotRemoveVoteParam() private {
        _addVoteParam(bytes4("vote"), 1, 1 days, 1 days, 8000, 3 days);
        _submitProposal(ADAPTER_SLOT, bytes28("1"), false, 0, bytes4("vote"), USER);

        vm.prank(VOTING);
        vm.expectRevert("Agora: parameters still used");
        agora.changeVoteParams(
            bytes4("vote"),
            IAgora.Consensus.NO_VOTE,
            1 days,
            1 days,
            8000,
            3 days
        );
    }

    /*////////////////////////////////
            submitProposal()
    ////////////////////////////////*/
    function testSubmitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproved,
        uint32 minStartTime
    ) public {
        vm.warp(1000);
        bytes32 proposalId = _submitProposal(
            slot,
            adapterProposalId,
            adminApproved,
            minStartTime,
            VOTE_STANDARD,
            USER
        );
        if (minStartTime == 0) minStartTime = uint32(block.timestamp);

        assertTrue(agora.getProposal(proposalId).active, "active");
        assertEq(agora.getProposal(proposalId).adminApproved, adminApproved, "approval");
        assertEq(agora.getProposal(proposalId).createdAt, block.timestamp, "created at");
        assertEq(agora.getProposal(proposalId).minStartTime, minStartTime, "min start time");
        assertEq(agora.getProposal(proposalId).initiater, USER, "initiater");
        assertEq(agora.getVoteParams(VOTE_STANDARD).utilisation, 1);
    }

    function testCannotSubmitProposal() public {
        vm.warp(1000);
        vm.startPrank(ADAPTER_ADDR);
        vm.expectRevert("Agora: unknown vote params");
        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, bytes4("?"), 500, USER);

        vm.expectRevert("Agora: wrong starting time");
        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, VOTE_DEFAULT, 500, USER);

        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, VOTE_DEFAULT, 0, USER);

        vm.expectRevert("Agora: proposal already exist");
        agora.submitProposal(ADAPTER_SLOT, bytes28("1"), true, VOTE_DEFAULT, 0, USER);
    }

    event ProposalSubmitted(
        bytes4 indexed slot,
        address indexed from,
        bytes4 indexed voteParam,
        bytes32 proposalId
    );

    function testEmitOnSubmitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproval,
        uint32 minStartTime
    ) public {
        bytes32 proposalId = _prepareSubmitProposal(slot, adapterProposalId, minStartTime);
        vm.expectEmit(true, true, true, true, AGORA);
        emit ProposalSubmitted(slot, USER, VOTE_DEFAULT, proposalId);
        agora.submitProposal(
            slot,
            adapterProposalId,
            adminApproval,
            VOTE_DEFAULT,
            minStartTime,
            USER
        );
    }

    /*////////////////////////////////
            getProposalStatus()
    ////////////////////////////////*/
    function testGetProposalStatus() public {
        // long standby proposal with admin validation
        vm.warp(1000);
        bytes32 proposalId = _submitProposal(
            ADAPTER_SLOT,
            bytes28("1"),
            false,
            type(uint32).max,
            VOTE_STANDARD,
            USER
        );

        // 0. UNKNOWN
        assertEq(uint8(agora.getProposalStatus(bytes32("1"))), 0);

        // 1. VALIDATION
        assertEq(uint8(agora.getProposalStatus(proposalId)), 1);

        vm.warp(1000 + _standardVote().adminValidationPeriod);

        // 2. STANDBY
        assertEq(uint8(agora.getProposalStatus(proposalId)), 2); // standby

        // short standby without validation
        vm.warp(1000);
        proposalId = _submitProposal(ADAPTER_SLOT, bytes28("2"), true, 2000, VOTE_STANDARD, USER);

        // 2. STANDBY
        assertEq(uint8(agora.getProposalStatus(proposalId)), 2);

        vm.warp(3000);

        // 3. ONGOING
        assertEq(uint8(agora.getProposalStatus(proposalId)), 3);

        vm.warp(3200 + _standardVote().votingPeriod);

        // 4. CLOSED
        assertEq(uint8(agora.getProposalStatus(proposalId)), 4);

        vm.warp(3200 + _standardVote().votingPeriod + _standardVote().gracePeriod);

        // 6. TO_FINALIZE
        assertEq(uint8(agora.getProposalStatus(proposalId)), 6);

        vm.prank(VOTING);
        agora.finalizeProposal(proposalId, USER, IAgora.VoteResult.ACCEPTED);

        // 7. ARCHIVED
        assertEq(uint8(agora.getProposalStatus(proposalId)), 7);

        // postpone startTime
        vm.warp(1000);
        proposalId = _submitProposal(ADAPTER_SLOT, bytes28("3"), true, 2000, VOTE_STANDARD, USER);
        vm.warp(1001 + _standardVote().adminValidationPeriod);
        assertEq(uint8(agora.getProposalStatus(proposalId)), 3);
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
            uint32(block.timestamp),
            VOTE_STANDARD,
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

    /*////////////////////////////////
              suspendProposal()
    ////////////////////////////////*/
    function testSuspendProposal() public {
        vm.warp(1000);
        bytes32 proposalId = _submitProposal(
            ADAPTER_SLOT,
            bytes28("1"),
            false,
            2000,
            VOTE_STANDARD,
            USER
        );

        // VALIDATION
        vm.prank(VOTING);
        agora.suspendProposal(proposalId);
        assertTrue(agora.getProposal(proposalId).suspended);
        assertEq(agora.getProposal(proposalId).suspendedAt, 0);

        // STANDBY
        proposalId = _submitProposal(ADAPTER_SLOT, bytes28("2"), true, 2000, VOTE_STANDARD, USER);
        vm.prank(VOTING);
        agora.suspendProposal(proposalId);
        assertTrue(agora.getProposal(proposalId).suspended);
        assertEq(agora.getProposal(proposalId).suspendedAt, 0);

        // ONGOING
        proposalId = _submitProposal(ADAPTER_SLOT, bytes28("3"), true, 2000, VOTE_STANDARD, USER);
        vm.warp(3000);
        vm.prank(VOTING);
        agora.suspendProposal(proposalId);
        assertTrue(agora.getProposal(proposalId).suspended);
        assertEq(agora.getProposal(proposalId).suspendedAt, 3000);

        // CLOSED
        proposalId = _submitProposal(ADAPTER_SLOT, bytes28("4"), true, 0, VOTE_STANDARD, USER);
        vm.warp(3001 + _standardVote().votingPeriod);
        vm.prank(VOTING);
        agora.suspendProposal(proposalId);
        assertTrue(agora.getProposal(proposalId).suspended);
        assertEq(agora.getProposal(proposalId).suspendedAt, 1);
    }

    function testCannotSuspendProposal() public {
        // UNKNOWN
        vm.prank(VOTING);
        vm.expectRevert("Agora: cannot suspend the proposal");
        agora.suspendProposal(bytes32("1"));

        // TO_FINALIZE
        bytes32 proposalId = _submitProposal(
            ADAPTER_SLOT,
            bytes28("1"),
            true,
            2000,
            VOTE_STANDARD,
            USER
        );
        vm.warp(2001 + _standardVote().votingPeriod + _standardVote().gracePeriod);
        vm.prank(VOTING);
        vm.expectRevert("Agora: cannot suspend the proposal");
        agora.suspendProposal(proposalId);
    }

    function testCannotSubmitVote() private {
        // outside voting period
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
