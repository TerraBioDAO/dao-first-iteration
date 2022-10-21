// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../abstracts/ProposerAdapter.sol";
import "../interfaces/IBank.sol";
import "../interfaces/IAgora.sol";

contract Voting is ProposerAdapter {
    enum ProposalType {
        CONSULTATION,
        VOTE_PARAMS
    }

    struct Consultation {
        string title;
        string description;
        address initiater;
    }

    struct ProposedVoteParam {
        IAgora.Consensus consensus;
        uint32 votingPeriod;
        uint32 gracePeriod;
        uint32 threshold;
    }

    struct Proposal {
        ProposalType proposalType;
        Consultation consultation;
        ProposedVoteParam voteParam;
    }

    mapping(bytes28 => Consultation) private _proposals;

    constructor(address core) Adapter(core, Slot.VOTING) {}

    function submitVote(
        bytes32 proposalId,
        uint256 value,
        uint96 deposit,
        uint32 lockPeriod,
        uint96 advanceDeposit
    ) external onlyMember {
        // get vote Weight
        uint96 voteWeight = _getBank().newCommitment(
            msg.sender,
            proposalId,
            deposit,
            lockPeriod,
            advanceDeposit
        );

        // submit vote
        _getAgora().submitVote(proposalId, msg.sender, uint128(voteWeight), value);
    }

    function withdrawAmount(uint128 amount) external onlyMember {
        _getBank().withdrawAmount(msg.sender, amount);
    }

    function finalizeProposal(bytes32 proposalId) external onlyMember {
        _getAgora().finalizeProposal(proposalId, msg.sender);
    }

    function proposeNewVoteParams(
        string calldata name,
        IAgora.Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold
    ) external onlyMember {
        bytes4 voteId = bytes4(keccak256(bytes(name)));
        require(
            _getAgora().getVoteParams(voteId).votingPeriod == 0,
            "Voting: cannot replace vote params"
        );

        ProposedVoteParam memory pvp = ProposedVoteParam(
            consensus,
            votingPeriod,
            gracePeriod,
            threshold
        );
        Consultation memory emptyConsultation;

        Proposal memory p = Proposal(ProposalType.VOTE_PARAMS, emptyConsultation, pvp);
        bytes28 proposalId = bytes28(keccak256(abi.encode(p)));
    }

    function addNewVoteParams(
        string memory name,
        IAgora.Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold
    ) external onlyAdmin {
        bytes4 voteId = bytes4(keccak256(bytes(name)));
        _getAgora().changeVoteParams(voteId, consensus, votingPeriod, gracePeriod, threshold);
    }

    function removeVoteParams(bytes4 voteId) external onlyAdmin {
        _getAgora().changeVoteParams(voteId, IAgora.Consensus.NO_VOTE, 0, 0, 0);
    }

    function _getBank() internal view returns (IBank) {
        return IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));
    }

    function _getAgora() internal view returns (IAgora) {
        return IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
    }
}
