// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/extensions/IAgora.sol";
import "src/adapters/Voting.sol";

contract Agora_test is BaseDaoTest {
    Agora public agora;

    address public AGORA;
    address public VOTING;
    bytes4 public constant VOTE_STANDARD = bytes4(keccak256("standard"));

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        VOTING = _branchMock(Slot.VOTING, false);
    }

    function testAddVoteParam() public {
        vm.prank(VOTING);
        agora.changeVoteParams(VOTE_STANDARD, IAgora.Consensus.MEMBER, 50, 50, 7500);

        IAgora.VoteParam memory param = IAgora.VoteParam(IAgora.Consensus.MEMBER, 50, 50, 7500, 0);

        IAgora.VoteParam memory storedParam = agora.getVoteParams(VOTE_STANDARD);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.utilisation, param.utilisation);
    }

    function testCannotAddNewVoteParam() public {
        vm.expectRevert("CoreGuard: not the right adapter");
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
        vm.prank(VOTING);
        vm.expectEmit(true, true, false, false, address(agora));
        emit VoteParamsChanged(voteId, true);
        agora.changeVoteParams(voteId, IAgora.Consensus.MEMBER, 50, 50, 7500);
    }

    function testRemoveVoteParam() public {
        // wait for the utilisation case
        // when a vote/ proposal is started
    }
}
