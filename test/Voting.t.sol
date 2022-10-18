// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/extensions/IAgora.sol";
import "src/adapters/Voting.sol";

contract Voting_test is BaseDaoTest {
    Agora public agora;
    Voting public voting;

    address public AGORA;
    address public VOTING;
    bytes4 public constant VOTE_STANDARD = bytes4(keccak256("standard"));

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        voting = new Voting(address(dao));
        VOTING = address(voting);
        _branch(Slot.VOTING, VOTING);
    }

    // changeVoteParams
    function testAddNewVoteParams() public {
        vm.prank(ADMIN);
        voting.addNewVoteParams("standard", IAgora.Consensus.MEMBER, 50, 50, 7500);

        IAgora.VoteParam memory param = IAgora.VoteParam(IAgora.Consensus.MEMBER, 50, 50, 7500, 0);

        IAgora.VoteParam memory storedParam = agora.getVoteParams(VOTE_STANDARD);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.utilisation, param.utilisation);
    }

    function testRemoveVoteParams() public {
        vm.startPrank(ADMIN);
        voting.addNewVoteParams("standard", IAgora.Consensus.MEMBER, 50, 50, 7500);

        voting.removeVoteParams(VOTE_STANDARD);

        IAgora.VoteParam memory defaultParam;
        IAgora.VoteParam memory storedParam = agora.getVoteParams(VOTE_STANDARD);

        assertEq(uint256(storedParam.consensus), uint256(defaultParam.consensus));
        assertEq(storedParam.votingPeriod, defaultParam.votingPeriod);
        assertEq(storedParam.gracePeriod, defaultParam.gracePeriod);
        assertEq(storedParam.threshold, defaultParam.threshold);
        assertEq(storedParam.utilisation, defaultParam.utilisation);
    }
}
