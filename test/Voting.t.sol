// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";
import "src/extensions/Agora.sol";
import "src/extensions/IAgora.sol";
import "src/adapters/Voting.sol";

contract Voting_test is Test {
    DaoCore public dao;
    Agora public agora;
    Voting public voting;

    address public constant ADMIN = address(500);
    address public VOTING;
    bytes4 public constant VOTE_STANDARD = bytes4(keccak256("standard"));

    function setUp() public {
        dao = new DaoCore(ADMIN, ADMIN);
        agora = new Agora(address(dao));
        voting = new Voting(address(dao));
        VOTING = address(voting);

        vm.startPrank(ADMIN);
        dao.changeSlotEntry(Slot.AGORA, address(agora));
        dao.changeSlotEntry(Slot.VOTING, VOTING);
        vm.stopPrank();
    }

    // changeVoteParams
    function testAddNewVoteParams() public {
        vm.prank(ADMIN);
        voting.addNewVoteParams(
            "standard",
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

    function testRemoveVoteParams() public {
        vm.startPrank(ADMIN);
        voting.addNewVoteParams(
            "standard",
            IAgora.Consensus.MEMBER,
            IAgora.VoteType.YES_NO,
            50,
            50,
            7500,
            false
        );

        voting.removeVoteParams(VOTE_STANDARD);

        IAgora.VoteParam memory defaultParam;
        IAgora.VoteParam memory storedParam = agora.getVoteParams(VOTE_STANDARD);

        assertEq(uint256(storedParam.consensus), uint256(defaultParam.consensus));
        assertEq(uint256(storedParam.voteType), uint256(defaultParam.voteType));
        assertEq(storedParam.votingPeriod, defaultParam.votingPeriod);
        assertEq(storedParam.gracePeriod, defaultParam.gracePeriod);
        assertEq(storedParam.threshold, defaultParam.threshold);
        assertEq(storedParam.adminValidation, defaultParam.adminValidation);
        assertEq(storedParam.utilisation, defaultParam.utilisation);
    }
}
