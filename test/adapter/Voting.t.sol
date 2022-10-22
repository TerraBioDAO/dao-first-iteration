// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/extensions/Bank.sol";
import "src/interfaces/IAgora.sol";
import "src/adapters/Voting.sol";

contract Voting_test is BaseDaoTest {
    Agora public agora;
    Bank public bank;
    Voting public voting;

    address public AGORA;
    address public BANK;
    address public VOTING;
    bytes4 public constant VOTE_CUSTOM = bytes4(keccak256(bytes("vote-custom")));

    function setUp() public {
        _deployDao(address(501));
        _deployTBIO();

        agora = new Agora(address(dao));
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);

        bank = new Bank(address(dao), address(tbio));
        BANK = address(bank);
        _branch(Slot.BANK, BANK);

        voting = new Voting(address(dao));
        VOTING = address(voting);
        _branch(Slot.VOTING, VOTING);
    }

    // changeVoteParams
    function testAddNewVoteParams(
        uint8 consensusNb,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) public {
        vm.assume((consensusNb == 1 || consensusNb == 2) && votingPeriod > 0 && threshold < 10000);
        IAgora.Consensus consensus = IAgora.Consensus(consensusNb);
        vm.prank(ADMIN);
        voting.addNewVoteParams(
            "vote-custom",
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );

        IAgora.VoteParam memory param = IAgora.VoteParam(
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod,
            0
        );

        IAgora.VoteParam memory storedParam = agora.getVoteParams(VOTE_CUSTOM);

        assertEq(uint256(storedParam.consensus), uint256(param.consensus));
        assertEq(storedParam.votingPeriod, param.votingPeriod);
        assertEq(storedParam.gracePeriod, param.gracePeriod);
        assertEq(storedParam.threshold, param.threshold);
        assertEq(storedParam.adminValidationPeriod, param.adminValidationPeriod);
        assertEq(storedParam.utilisation, param.utilisation);
    }

    function testRemoveVoteParams() public {
        IAgora.VoteParam memory voteStandard = agora.getVoteParams(Slot.VOTE_STANDARD);
        assertTrue(voteStandard.votingPeriod > 0);
        assertTrue(voteStandard.gracePeriod > 0);
        assertTrue(voteStandard.threshold > 0);
        assertTrue(voteStandard.adminValidationPeriod > 0);
        assertTrue(uint256(voteStandard.consensus) > 0);

        vm.startPrank(ADMIN);
        voting.removeVoteParams(Slot.VOTE_STANDARD);

        voteStandard = agora.getVoteParams(Slot.VOTE_STANDARD);
        assertFalse(voteStandard.votingPeriod > 0);
        assertFalse(voteStandard.gracePeriod > 0);
        assertFalse(voteStandard.threshold > 0);
        assertFalse(voteStandard.adminValidationPeriod > 0);
        assertFalse(uint256(voteStandard.consensus) > 0);
    }

    // submit vote
    function testSubmitVote() public {
        // new proposal
        // commitment in BANK
        // score in AGORA
    }
}
