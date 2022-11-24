// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/interfaces/IAgora.sol";
import "src/adapters/Voting.sol";

contract AgoraMock is Agora {
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

    function emitEvents() public {
        emit VoteParamsChanged(bytes4("1"), true);
        emit ProposalSubmitted(bytes4("2"), address(111), bytes4("3"), bytes32("123456"));
        emit ProposalFinalized(bytes32("123456"), address(222), true);
        emit MemberVoted(bytes32("123456"), address(333), 0, 567);
    }
}
