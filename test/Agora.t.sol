// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";
import "src/extensions/Agora.sol";
import "src/extensions/IAgora.sol";
import "src/adapters/Voting.sol";

contract FakeEntry {
    bytes4 public slotId;
    bool public isExtension;

    constructor(bytes4 slot, bool isExt) {
        slotId = slot;
        isExtension = isExt;
    }
}

contract Agora_test is Test {
    DaoCore public dao;
    Agora public agora;

    address public constant ADMIN = address(500);
    address public VOTING;
    bytes4 public constant VOTE_STANDARD = bytes4(keccak256("standard"));

    function _newEntry(bytes4 slot, bool isExt) internal returns (address entry) {
        entry = address(new FakeEntry(slot, isExt));
    }

    function setUp() public {
        dao = new DaoCore(ADMIN);
        agora = new Agora(address(dao));
        VOTING = _newEntry(Slot.VOTING, false);

        vm.startPrank(ADMIN);
        dao.changeSlotEntry(Slot.AGORA, address(agora));
        dao.changeSlotEntry(Slot.VOTING, VOTING);
        vm.stopPrank();
    }

    function testAddVoteParam() public {
        vm.prank(VOTING);
        agora.changeVoteParams(
            VOTE_STANDARD,
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            50,
            50,
            7500,
            false
        );

        IAgora.VoteParam memory param = IAgora.VoteParam(
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            50,
            50,
            7500,
            false,
            0
        );

        IAgora.VoteParam memory storedParam = agora.getVoteParams(VOTE_STANDARD);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(uint256(storedParam.voteType), uint256(param.voteType));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.adminValidation, param.adminValidation);
        assertEq(storedParam.utilisation, param.utilisation);
    }

    function testCannotAddNewVoteParam() public {
        vm.expectRevert("CoreGuard: not the right adapter");
        agora.changeVoteParams(
            VOTE_STANDARD,
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            50,
            50,
            7500,
            false
        );

        vm.startPrank(VOTING);
        vm.expectRevert("Agora: wrong threshold or below min value");
        agora.changeVoteParams(
            VOTE_STANDARD,
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            50,
            50,
            750000,
            false
        );

        vm.expectRevert("Agora: below min period");
        agora.changeVoteParams(
            VOTE_STANDARD,
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            0,
            50,
            7500,
            false
        );

        agora.changeVoteParams(
            VOTE_STANDARD,
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            50,
            50,
            7500,
            false
        );
        vm.expectRevert("Agora: cannot replace params");
        agora.changeVoteParams(
            VOTE_STANDARD,
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            100,
            100,
            10000,
            false
        );
    }

    event VoteParamsChanged(bytes4 indexed voteId, bool indexed added);

    function testEmitOnVoteParam(bytes4 voteId) public {
        vm.prank(VOTING);
        vm.expectEmit(true, true, false, false, address(agora));
        emit VoteParamsChanged(voteId, true);
        agora.changeVoteParams(
            voteId,
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            50,
            50,
            7500,
            false
        );
    }

    function testRemoveVoteParam() public {
        // wait for the utilisation case
        // when a vote/ proposal is started
    }
}
