// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "test/mocks/AgoraMock.sol";
import "src/interfaces/IAgora.sol";
import "src/adapters/Voting.sol";

contract Agora_test is BaseDaoTest {
    /* ///////////////////////////////
         Rewrite Events in IAgora
    not available in the current scope
              COPY / PASTE
              and adjust emitEvents()
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
        bool indexed accepted
    );

    event MemberVoted(
        bytes32 indexed proposalId,
        address indexed voter,
        uint256 indexed value,
        uint256 voteWeight
    );
    ////////////////////////////////

    using Slot for bytes28;

    Agora public agora;
    AgoraMock public agoraMock;

    address public AGORA;
    address public VOTING;
    address public ADAPTER_ADDR;
    address public constant USER = address(5);
    bytes4 public constant ADAPTER_SLOT = bytes4("a");
    bytes4 public constant VOTE_MEMBER = bytes4(keccak256("member"));
    bytes4 public constant VOTE_DEFAULT = bytes4(0);

    // test iterations count to restrict number of fuzzing tests
    uint256 _iterationsCount;

    // presets
    bytes4 public constant VOTE_STANDARD_COPY = bytes4(keccak256("vote-standard-copy"));
    bytes4 public constant VOTE_MEMBER_COPY = bytes4(keccak256("vote-member-copy"));
    bytes32 proposalId_AdminApproved_VoteStandard_User;

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        VOTING = _branchMock(Slot.VOTING, false);
        ADAPTER_ADDR = _branchMock(ADAPTER_SLOT, false);

        //Mocks
        agoraMock = new AgoraMock(address(dao));

        // Preset Some configurations
        _iterationsCount = 0;

        vm.startPrank(VOTING);
        agora.changeVoteParam(
            true, // isToAdd
            VOTE_DEFAULT,
            IAgora.Consensus.TOKEN,
            86400,
            86400,
            8000,
            86400
        );
        agora.changeVoteParam(
            true,
            VOTE_MEMBER,
            IAgora.Consensus.MEMBER,
            86400,
            86400,
            8000,
            86400
        );
        agora.changeVoteParam(
            true,
            VOTE_STANDARD_COPY,
            IAgora.Consensus.TOKEN,
            7 days,
            3 days,
            8000,
            7 days
        );
        agora.changeVoteParam(
            true,
            VOTE_MEMBER_COPY,
            IAgora.Consensus.MEMBER,
            7 days,
            3 days,
            8000,
            7 days
        );

        vm.stopPrank();

        proposalId_AdminApproved_VoteStandard_User = _submitProposal(
            ADAPTER_SLOT,
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
    function _prepareAddVoteParam(
        bytes4 voteId,
        uint8 consensus,
        uint32 votingPeriod,
        uint32, //gracePeriod,
        uint32 threshold,
        uint32 //adminValidationPeriod
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
        agora.changeVoteParam(
            true,
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
        assertEq(storedParam.usesCount, 0);
    }

    /* ////////////////////////////////
        test Events copied from interface
    ////////////////////////////////*/
    function testEvents() public {
        vm.expectEmit(true, true, false, false, address(agoraMock));
        emit VoteParamsChanged(bytes4("1"), true);
        vm.expectEmit(true, true, true, true, address(agoraMock));
        emit ProposalSubmitted(bytes4("2"), address(111), bytes4("3"), bytes32("123456"));
        vm.expectEmit(true, true, true, false, address(agoraMock));
        emit ProposalFinalized(bytes32("123456"), address(222), true);
        vm.expectEmit(true, true, true, true, address(agoraMock));
        emit MemberVoted(bytes32("123456"), address(333), 0, 567);
        agoraMock.emitEvents();
    }

    /* ////////////////////////////////
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
        assertEq(storedParam.usesCount, param.usesCount);
    }

    function testCannotAddNewVoteParam() public {
        bytes4 NEW_VOTE = bytes4("5");
        vm.expectRevert("Cores: not the right adapter");
        agora.changeVoteParam(true, NEW_VOTE, IAgora.Consensus.MEMBER, 50, 50, 7500, 777);

        vm.startPrank(VOTING);
        vm.expectRevert("Agora: wrong threshold or below min value");
        agora.changeVoteParam(true, NEW_VOTE, IAgora.Consensus.MEMBER, 50, 50, 750000, 777);

        vm.expectRevert("Agora: below min period");
        agora.changeVoteParam(true, NEW_VOTE, IAgora.Consensus.MEMBER, 0, 50, 7500, 777);

        agora.changeVoteParam(true, NEW_VOTE, IAgora.Consensus.MEMBER, 50, 50, 7500, 777);
        vm.expectRevert("Agora: cannot replace params");
        agora.changeVoteParam(true, NEW_VOTE, IAgora.Consensus.MEMBER, 100, 100, 10000, 777);
    }

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
        agora.changeVoteParam(
            true,
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
        assertEq(storedParam.usesCount, param.usesCount);

        vm.prank(VOTING);
        agora.changeVoteParam(
            false, // remove
            voteId,
            IAgora.Consensus.UNINITIATED,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );

        storedParam = agora.getVoteParams(voteId);

        assertEq(uint256(storedParam.consensus), uint256(IAgora.Consensus.UNINITIATED));
        assertEq(storedParam.votingPeriod, 0);
        assertEq(storedParam.gracePeriod, 0);
        assertEq(storedParam.threshold, 0);
        assertEq(storedParam.adminValidationPeriod, 0);
        assertEq(storedParam.usesCount, 0);
    }

    function testCannotRemoveVoteParam() private {
        _addVoteParam(bytes4("vote"), 1, 1 days, 1 days, 8000, 3 days);
        _submitProposal(ADAPTER_SLOT, bytes28("1"), false, 0, bytes4("vote"), USER);

        vm.prank(VOTING);
        vm.expectRevert("Agora: parameters still used");
        agora.changeVoteParam(
            false, // remove
            bytes4("vote"),
            IAgora.Consensus.UNINITIATED,
            1 days,
            1 days,
            8000,
            3 days
        );
    }

    /* ////////////////////////////////
            _addVoteParam()
    ////////////////////////////////*/
    function test_addVoteParam(
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

        vm.expectEmit(true, true, false, false, address(agoraMock));
        // We emit the event we expect to see.
        emit VoteParamsChanged(voteId, true);
        agoraMock.addVoteParam(
            voteId,
            param.consensus,
            param.votingPeriod,
            param.gracePeriod,
            param.threshold,
            param.adminValidationPeriod
        );

        IAgora.VoteParam memory storedParam = agoraMock.getVoteParams(voteId);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.adminValidationPeriod, param.adminValidationPeriod);
        assertEq(storedParam.usesCount, param.usesCount);
    }

    function test_cannotAddNewVoteParam() public {
        uint32 BAD_VOTING_PERIOD = 0;
        uint32 BAD_THRESHOLD = 10001;
        // A vote param
        bytes4 voteParamId = bytes4(keccak256("a-vote-param"));
        agoraMock.addVoteParam(voteParamId, IAgora.Consensus.MEMBER, 50, 50, 7500, 700);
        vm.expectRevert("Agora: cannot replace params");
        agoraMock.addVoteParam(
            voteParamId,
            IAgora.Consensus.MEMBER,
            BAD_VOTING_PERIOD,
            3 days,
            BAD_THRESHOLD,
            7 days
        );

        // Another vote param
        voteParamId = bytes4(keccak256("another-vote-param"));

        vm.expectRevert("Agora: bad consensus");
        agoraMock.addVoteParam(
            voteParamId,
            IAgora.Consensus.UNINITIATED,
            BAD_VOTING_PERIOD,
            123,
            BAD_THRESHOLD,
            456
        );

        vm.expectRevert("Agora: below min period");
        agoraMock.addVoteParam(
            voteParamId,
            IAgora.Consensus.MEMBER,
            BAD_VOTING_PERIOD,
            123,
            BAD_THRESHOLD,
            456
        );

        vm.expectRevert("Agora: wrong threshold or below min value");
        agoraMock.addVoteParam(voteParamId, IAgora.Consensus.MEMBER, 50, 123, BAD_THRESHOLD, 456);
    }

    /* ////////////////////////////////
            _removeVoteParam()
    ////////////////////////////////*/
    function test_removeVoteParam(
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
        agoraMock.addVoteParam(
            voteParamId,
            param.consensus,
            param.votingPeriod,
            param.gracePeriod,
            param.threshold,
            param.adminValidationPeriod
        );

        vm.expectEmit(true, false, false, false, address(agoraMock));
        emit VoteParamsChanged(voteParamId, false);
        agoraMock.removeVoteParam(voteParamId);

        IAgora.VoteParam memory storedParam = agoraMock.getVoteParams(voteParamId);

        assertEq(uint256(storedParam.consensus), 0);
        assertEq(storedParam.votingPeriod, 0);
        assertEq(storedParam.gracePeriod, 0);
        assertEq(storedParam.threshold, 0);
        assertEq(storedParam.adminValidationPeriod, 0);
        assertEq(storedParam.usesCount, 0);
    }

    /* ////////////////////////////////
            changeVoteParam()
    ////////////////////////////////*/
    function _changeVoteParam(bool isToAdd, bool isEventExpected) internal {
        bytes4 voteParamId = bytes4(keccak256("a-vote-param"));
        if (isEventExpected) {
            vm.expectEmit(true, true, false, false, AGORA);
            emit VoteParamsChanged(voteParamId, true);
        }
        agora.changeVoteParam(
            isToAdd,
            voteParamId,
            IAgora.Consensus.MEMBER,
            1 days,
            2 days,
            7500,
            7 days
        );
    }

    function testChangeVoteParam_Add() public {
        vm.prank(VOTING);
        _changeVoteParam(true, true);

        vm.prank(VOTING);
        vm.expectRevert("Agora: cannot replace params");
        _changeVoteParam(true, false);

        vm.prank(VOTING);
        _changeVoteParam(false, false);
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
        agora.finalizeProposal(proposalId, USER, true);

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
        vm.warp(1 days);
        bytes32 proposalId = _submitProposal(
            ADAPTER_SLOT,
            bytes28(keccak256("a-proposal-id")),
            true, //adminApproval
            1 days, //minStartTime
            VOTE_STANDARD,
            USER
        );

        uint8 value = 0;
        uint128 voteWeight = 10**20;

        vm.warp(1 days + _standardVote().votingPeriod + 1);
        vm.prank(VOTING);
        vm.expectRevert("Agora: outside voting period");
        agora.submitVote(proposalId, USER, voteWeight, value);
    }

    function testSubmitMemberVote() public {
        // add default member vote at `bytes4("1")`
    }

    /* ////////////////////////////////
              _calculateVoteResult()
              getVoteResult()
    ////////////////////////////////*/
    function setUp_GetVoteResult(IAgora.Consensus consensus, uint32 threshold)
        internal
        returns (bytes32 proposalId)
    {
        bytes4 aVoteParamId = bytes4(bytes32(hex"eeee"));
        vm.warp(1 days);
        vm.prank(VOTING);
        agora.changeVoteParam(true, aVoteParamId, consensus, 7 days, 3 days, threshold, 7 days);

        return
            _submitProposal(
                ADAPTER_SLOT,
                bytes28(keccak256("a-proposal-id")),
                true, //adminApproval
                1 days, //minStartTime
                aVoteParamId,
                USER
            );
    }

    function testGetVoteResult_Consensus_TOKEN() public {
        bytes32 proposalId = setUp_GetVoteResult(IAgora.Consensus.TOKEN, 5001);

        uint8 value = 0; // yes
        uint128 voteWeight = 10**20;
        vm.prank(VOTING);
        agora.submitVote(proposalId, USER, voteWeight, value);
        bool accepted = agora.getVoteResult(proposalId);
        assertTrue(accepted);

        address anotherUser = address(6);
        value = 1; // no
        voteWeight = 10**20;
        vm.prank(VOTING);
        agora.submitVote(proposalId, anotherUser, voteWeight, value);
        accepted = agora.getVoteResult(proposalId);
        assertFalse(accepted);

        anotherUser = address(7);
        value = 0; // yes
        voteWeight = 10**18; // to reach 50,01%
        vm.prank(VOTING);
        agora.submitVote(proposalId, anotherUser, voteWeight, value);
        accepted = agora.getVoteResult(proposalId);
        assertTrue(accepted);
    }

    function testGetVoteResult_Consensus_MEMBER() public {
        bytes32 proposalId = setUp_GetVoteResult(IAgora.Consensus.MEMBER, 6666);

        uint8 value = 0; // yes
        uint128 voteWeight = 1;
        vm.prank(VOTING);
        agora.submitVote(proposalId, USER, voteWeight, value);
        bool accepted = agora.getVoteResult(proposalId);
        assertTrue(accepted);

        address anotherUser = address(6);
        value = 1; // no

        vm.prank(VOTING);
        agora.submitVote(proposalId, anotherUser, voteWeight, value);
        accepted = agora.getVoteResult(proposalId);
        assertFalse(accepted);

        // to reach the 66.66%
        anotherUser = address(7);
        value = 0; // yes

        vm.prank(VOTING);
        agora.submitVote(proposalId, anotherUser, voteWeight, value);
        accepted = agora.getVoteResult(proposalId);
        assertTrue(accepted);
    }

    function testGetVoteResult_fuzz(
        uint256 randomNumber,
        uint32 voteParamId_,
        uint8 votesCount_,
        uint8 consensus_,
        uint8 thresholdPercent
    ) public {
        // Limit fuzzing iterations
        uint256 wantedIterationsCount = 10;
        // assuming iterations count is set to 256
        if (bound(randomNumber, 1, 256) > wantedIterationsCount) {
            return;
        }

        bytes4 voteParamId = bytes4(uint32(bound(voteParamId_, 16, type(uint32).max)));
        uint32 threshold = uint32(bound(thresholdPercent, 1, 100) * 100);
        IAgora.Consensus consensus = IAgora.Consensus(bound(consensus_, 1, 2));
        uint8 votesCount = uint8(bound(votesCount_, 10, 999));

        vm.warp(1000);
        vm.prank(VOTING);
        agora.changeVoteParam(true, voteParamId, consensus, 7 days, 3 days, threshold, 7 days);

        bytes32 proposalId = _submitProposal(
            ADAPTER_SLOT,
            bytes28(keccak256(abi.encodePacked("a-proposal-id", randomNumber))),
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

        //bool accepted = agora.getVoteResult(proposalId);

        vm.stopPrank();
    }

    function testFinalizeProposal() public {
        bytes32 proposalId = proposalId_AdminApproved_VoteStandard_User;
        vm.prank(ADAPTER_ADDR);

        vm.expectEmit(true, true, true, false, AGORA);
        emit ProposalFinalized(proposalId, address(123), true);
        agora.finalizeProposal(proposalId, address(123), true);

        IAgora.Proposal memory proposal_ = agora.getProposal(proposalId);
        assertTrue(proposal_.proceeded);
        // test Archive values
    }

    function testCannotFinalizeProposal() private {
        // include vote rejected
    }
}
