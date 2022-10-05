// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "../guards/SlotGuard.sol";

contract Voting is SlotGuard {
    event VoteSessionOpened(
        bytes4 indexed slot,
        bytes4 indexed voteParams,
        bytes32 proposalId,
        uint64 startTime,
        uint64 endTime
    );

    // y/n
    // consultation / execution
    enum VoteType {UNANIMITY}

    struct Vote {
        uint64 startTime;
        VoteType voteType;
        uint256 score;
        uint256 filling;
    }

    struct VoteParameter {
        VoteType voteType;
        uint64 votingPeriod;
        uint64 gracePeriod;
        uint64 delay;
    }

    mapping(bytes32 => Vote) public sessions;
    mapping(bytes32 => mapping(address => uint256)) public votes;
    mapping(bytes4 => VoteParameter) public voteConfigs;

    constructor(address core) SlotGuard(core, Slot.VOTING) {}

    function openVoteSession(bytes32 proposalId, bytes4 voteConfig)
        external
    {
        // ONLY ADAPTERS

        VoteParameter memory vp = voteConfigs[voteConfig];
        require(vp.votingPeriod > 0, "Voting: wrong vote params");

        Vote memory vote = sessions[proposalId];
        require(vote.startTime == 0, "Voting: session already opened");

        uint64 startTime = uint64(block.timestamp + vp.delay);
        vote.startTime = startTime;
        vote.voteType = vp.voteType;

        emit VoteSessionOpened(
            bytes4(proposalId),
            voteConfig,
            proposalId,
            startTime,
            startTime + vp.votingPeriod
            );
    }

    function submitVote(bytes32 proposalId, uint256 vote)
        external
        onlyMember
    {
        require(
            votes[proposalId][msg.sender] == 0,
            "Voting: vote already submitted"
        );
    }
}
