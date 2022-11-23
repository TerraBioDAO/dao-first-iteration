// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/interfaces/IAgora.sol";
import "src/adapters/Voting.sol";

contract Agora_ is Agora {
    constructor(address core) Agora(core) {}

    function addVoteParam(
        bytes4 voteId,
        IAgora.Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        _addVoteParam(
            voteId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
    }

    function removeVoteParam(bytes4 voteParamId) public {
        _removeVoteParam(voteParamId);
    }
}

contract Agora_test is BaseDaoTest {
    /* ///////////////////////////////
         Rewrite Events in IAgora
    not available in the current scope
              COPY / PASTE
    ////////////////////////////////*/
    event VoteParamsChanged(bytes4 indexed voteParamId, bool indexed added); // add consensus?

    event ProposalSubmitted(
        bytes4 indexed slot,
        address indexed from,
        bytes4 indexed voteParam,
        bytes32 proposalId
    );

    event ProposalFinalized(
        bytes32 indexed proposalId,
        address indexed finalizer,
        IAgora.VoteResult indexed result
    );

    event MemberVoted(
        bytes32 indexed proposalId,
        address indexed voter,
        uint256 indexed value,
        uint256 voteWeight
    );
    ////////////////////////////////

    using Slot for bytes28;

    Agora_ public agora;

    address public AGORA;
    address public VOTING;
    address public ADAPTER_ADDR;
    address public constant USER = address(5);
    bytes4 public constant ADAPTER_SLOT = bytes4("a");
    bytes4 public constant VOTE_MEMBER = bytes4(keccak256("member"));
    bytes4 public constant VOTE_DEFAULT = bytes4(0);

    // presets
    bytes4 public constant VOTE_STANDARD_COPY = bytes4(keccak256("vote-standard-copy"));
    bytes4 public constant VOTE_MEMBER_COPY = bytes4(keccak256("vote-member-copy"));
    bytes32 proposalId_AdminApproved_VoteStandard_User;

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora_(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        VOTING = _branchMock(Slot.VOTING, false);
        ADAPTER_ADDR = _branchMock(ADAPTER_SLOT, false);

        // Preset Some configurations
        vm.startPrank(VOTING);
        agora.changeVoteParam(
            IAgora.VoteParamAction.ADD,
            VOTE_DEFAULT,
            IAgora.Consensus.TOKEN,
            86400,
            86400,
            8000,
            86400
        );
        agora.changeVoteParam(
            IAgora.VoteParamAction.ADD,
            VOTE_MEMBER,
            IAgora.Consensus.MEMBER,
            86400,
            86400,
            8000,
            86400
        );
        agora.changeVoteParam(
            IAgora.VoteParamAction.ADD,
            VOTE_STANDARD_COPY,
            IAgora.Consensus.TOKEN,
            7 days,
            3 days,
            8000,
            7 days
        );
        agora.changeVoteParam(
            IAgora.VoteParamAction.ADD,
            VOTE_MEMBER_COPY,
            IAgora.Consensus.MEMBER,
            7 days,
            3 days,
            8000,
            7 days
        );

        vm.stopPrank();

        proposalId_AdminApproved_VoteStandard_User = _submitProposal(
            bytes4(keccak256("a slot for proposalId_AdminApproved_VoteStandard_User")),
            bytes28(keccak256("proposalId_AdminApproved_VoteStandard_User")),
            true, //adminApproval
            uint32(1000), //minStartTime
            VOTE_STANDARD_COPY, // Consensus.TOKEN, 7 days, 3 days, 8000, 7 days
            USER
        );
    }

    /* ///////////////////////////////
                UTILS
    ////////////////////////////////*/
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
        assertEq(storedParam.usesCount, 0);
    }

    /* ////////////////////////////////
            _addVoteParam()
    ////////////////////////////////*/
    function testAddVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        vm.assume(voteId != bytes4(0) && voteId != VOTE_STANDARD);

        vm.prank(VOTING);

        IAgora.VoteParam memory param = IAgora.VoteParam(
            IAgora.Consensus(uint8(bound(consensus, 1, 2))),
            uint32(bound(votingPeriod, 1, type(uint256).max)),
            gracePeriod,
            uint32(bound(threshold, 0, 10000)),
            adminValidationPeriod,
            0
        );

        vm.expectEmit(true, true, false, false, AGORA);
        // We emit the event we expect to see.
        emit VoteParamsChanged(voteId, true);
        agora.addVoteParam(
            voteId,
            param.consensus,
            param.votingPeriod,
            param.gracePeriod,
            param.threshold,
            param.adminValidationPeriod
        );

        IAgora.VoteParam memory storedParam = agora.getVoteParams(voteId);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.adminValidationPeriod, param.adminValidationPeriod);
        assertEq(storedParam.usesCount, param.usesCount);
    }

    function testCannotAddNewVoteParam() public {
        uint32 BAD_VOTING_PERIOD = 0;
        uint32 BAD_THRESHOLD = 10001;
        // A vote param
        bytes4 VOTE_PARAM = bytes4(keccak256("a-vote-param"));
        agora.addVoteParam(VOTE_PARAM, IAgora.Consensus.MEMBER, 50, 50, 7500, 700);
        vm.expectRevert("Agora: cannot replace params");
        agora.addVoteParam(
            VOTE_PARAM,
            IAgora.Consensus.MEMBER,
            BAD_VOTING_PERIOD,
            123,
            BAD_THRESHOLD,
            456
        );

        // Another vote param
        // requirement to change param : consensus must to be UNKNOWN_PARAM
        VOTE_PARAM = bytes4(keccak256("another-vote-param"));
        agora.addVoteParam(VOTE_PARAM, IAgora.Consensus.UNKNOWN_PARAM, 50, 50, 7500, 700);
        vm.expectRevert("Agora: below min period");
        agora.addVoteParam(
            VOTE_PARAM,
            IAgora.Consensus.UNKNOWN_PARAM,
            BAD_VOTING_PERIOD,
            123,
            BAD_THRESHOLD,
            456
        );

        vm.expectRevert("Agora: wrong threshold or below min value");
        agora.addVoteParam(VOTE_PARAM, IAgora.Consensus.UNKNOWN_PARAM, 50, 123, BAD_THRESHOLD, 456);
    }

    /* ////////////////////////////////
            _removeVoteParam()
    ////////////////////////////////*/
    function testRemoveVoteParam(
        bytes4 voteParamId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        vm.assume(voteParamId != bytes4(0) && voteParamId != VOTE_STANDARD);
        IAgora.VoteParam memory param = IAgora.VoteParam(
            IAgora.Consensus(uint8(bound(consensus, 1, 2))),
            uint32(bound(votingPeriod, 1, type(uint256).max)),
            gracePeriod,
            uint32(bound(threshold, 0, 10000)),
            adminValidationPeriod,
            0
        );
        agora.addVoteParam(
            voteParamId,
            param.consensus,
            param.votingPeriod,
            param.gracePeriod,
            param.threshold,
            param.adminValidationPeriod
        );

        vm.expectEmit(true, false, false, false, AGORA);
        emit VoteParamsChanged(voteParamId, false);
        agora.removeVoteParam(voteParamId);

        IAgora.VoteParam memory storedParam = agora.getVoteParams(voteParamId);

        assertEq(uint256(storedParam.consensus), 0);
        assertEq(storedParam.votingPeriod, 0);
        assertEq(storedParam.gracePeriod, 0);
        assertEq(storedParam.threshold, 0);
        assertEq(storedParam.adminValidationPeriod, 0);
        assertEq(storedParam.usesCount, 0);
    }

    function testCannotRemoveVoteParam() public {
        bytes4 VOTE_PARAM_ID = bytes4(keccak256("a-vote-param"));
        agora.addVoteParam(VOTE_PARAM_ID, IAgora.Consensus.TOKEN, 1 days, 1 days, 8000, 3 days);
        _submitProposal(ADAPTER_SLOT, bytes28("1"), false, 0, VOTE_PARAM_ID, USER);

        vm.expectRevert("Agora: parameters still used");
        agora.removeVoteParam(VOTE_PARAM_ID);
    }

    /* ////////////////////////////////
            changeVoteParam()
    ////////////////////////////////*/
    function _changeVoteParam(IAgora.VoteParamAction action, bool isEventExpected) internal {
        bytes4 VOTE_PARAM_ID = bytes4(keccak256("a-vote-param"));
        if (isEventExpected) {
            vm.expectEmit(true, true, false, false, AGORA);
            emit VoteParamsChanged(VOTE_PARAM_ID, true);
        }
        agora.changeVoteParam(
            action,
            VOTE_PARAM_ID,
            IAgora.Consensus.MEMBER,
            1 days,
            2 days,
            7500,
            7 days
        );
    }

    function testChangeVoteParam_Add() public {
        vm.prank(VOTING);
        _changeVoteParam(IAgora.VoteParamAction.ADD, true);

        vm.prank(VOTING);
        vm.expectRevert("Agora: cannot replace params");
        _changeVoteParam(IAgora.VoteParamAction.ADD, false);

        vm.prank(VOTING);
        _changeVoteParam(IAgora.VoteParamAction.REMOVE, false);
    }

    /* ////////////////////////////////
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
        assertEq(agora.getVoteParams(VOTE_STANDARD).usesCount, 1);
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

    /* ////////////////////////////////
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

        vm.prank(ADAPTER_ADDR);
        agora.finalizeProposal(proposalId, USER, IAgora.VoteResult.ACCEPTED);

        // 7. ARCHIVED
        assertEq(uint8(agora.getProposalStatus(proposalId)), 7);

        // postpone startTime
        vm.warp(1000);
        proposalId = _submitProposal(ADAPTER_SLOT, bytes28("3"), true, 2000, VOTE_STANDARD, USER);
        vm.warp(1001 + _standardVote().adminValidationPeriod);
        assertEq(uint8(agora.getProposalStatus(proposalId)), 3);
    }

    /* ////////////////////////////////
              _submitVote()
              submitVote()
    ////////////////////////////////*/
    function testSubmitVote(uint8 value_, uint128 voteWeight_) public {
        vm.warp(1000);
        bytes32 proposalId = _submitProposal(
            ADAPTER_SLOT,
            bytes28(keccak256("a-proposal-id")),
            true, //adminApproval
            uint32(block.timestamp), //minStartTime
            VOTE_STANDARD,
            USER
        );

        uint8 value = uint8(bound(value_, 0, 2));
        uint128 voteWeight = uint128(bound(voteWeight_, 0, type(uint128).max));

        vm.warp(2000);
        vm.prank(VOTING);
        agora.submitVote(proposalId, USER, voteWeight, value);

        assertTrue(agora.hasVoted(proposalId, USER));
        assertEq(_score(proposalId).memberVoted, 1, "members");
        if (value == 0) {
            assertEq(_score(proposalId).nbYes, voteWeight, "yes");
        } else if (value == 1) {
            assertEq(_score(proposalId).nbNo, voteWeight, "no");
        } else {
            assertEq(_score(proposalId).nbNota, voteWeight, "nota");
        }
    }

    /* ////////////////////////////////
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

    function testCannotSubmitVote() public {
        // outside voting period
    }

    function testSubmitMemberVote() public {
        // add default member vote at `bytes4("1")`
    }

    /* ////////////////////////////////
              _calculateVoteResult()
              getVoteResult()
    ////////////////////////////////*/
    function testGetVoteResult(
        uint256 nonce,
        uint32 voteParamId_,
        uint8 votesCount_,
        uint8 consensus_,
        uint8 thresholdPercent
    ) public {
        // play with threshold

        bytes4 voteParamId = bytes4(uint32(bound(voteParamId_, 16, type(uint32).max)));
        uint32 threshold = uint32(bound(thresholdPercent, 1, 100) * 100);
        IAgora.Consensus consensus = IAgora.Consensus(bound(consensus_, 1, 2));
        uint8 votesCount = uint8(bound(votesCount_, 10, 999));

        vm.warp(1000);
        vm.prank(VOTING);
        agora.changeVoteParam(
            IAgora.VoteParamAction.ADD,
            voteParamId,
            consensus,
            7 days,
            3 days,
            threshold,
            7 days
        );

        bytes32 proposalId = _submitProposal(
            ADAPTER_SLOT,
            bytes28(keccak256(abi.encodePacked("a-proposal-id", nonce))),
            true, //adminApproval
            uint32(block.timestamp), //minStartTime
            VOTE_STANDARD_COPY,
            USER
        );

        vm.startPrank(VOTING);

        uint128 voteWeight = 1;
        uint8 i;
        while (i < votesCount) {
            if (consensus == IAgora.Consensus.TOKEN) {
                voteWeight = uint128(
                    bound(uint256(keccak256(abi.encodePacked(voteWeight, i))), 1, type(uint64).max)
                );
            }

            // new user for each vote
            // consensus_ : random number
            address aUser = address(uint160(uint256(keccak256(abi.encodePacked(consensus_, i)))));

            if (agora.hasVoted(proposalId, aUser)) {
                continue;
            }

            vm.warp(2000 + i);
            // consensus_: random value
            uint8 value = uint8(bound(uint256(keccak256(abi.encodePacked(consensus_, i))), 0, 2));
            agora.submitVote(proposalId, aUser, voteWeight, value);

            i++;
        }

        IAgora.VoteResult voteResult = agora.getVoteResult(proposalId);
        assertTrue(
            voteResult == IAgora.VoteResult.ACCEPTED || voteResult == IAgora.VoteResult.REJECTED
        );

        vm.stopPrank();
    }

    function testFinalizeProposal() private {
        // mock `IAdapter(adapter).finalizeProposal(bytes28(proposalId << 32));`
    }

    function testCannotFinalizeProposal() private {
        // include vote rejected
    }
}
