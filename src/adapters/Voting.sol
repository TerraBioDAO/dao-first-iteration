// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

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
        bytes4 voteParamId;
        IAgora.Consensus consensus;
        uint32 votingPeriod;
        uint32 gracePeriod;
        uint32 threshold;
        uint32 adminValidationPeriod;
    }

    struct VotingProposal {
        ProposalType proposalType;
        Consultation consultation;
        ProposedVoteParam voteParam;
    }

    mapping(bytes28 => VotingProposal) private _votingProposals;

    constructor(address core) Adapter(core, Slot.VOTING) {}

    function submitVote(
        bytes32 proposalId,
        uint256 value,
        uint96 deposit,
        uint32 lockPeriod,
        uint96 advancedDeposit
    ) external onlyMember {
        // get vote Weight
        uint96 voteWeight = _getBank().newCommitment(
            msg.sender,
            proposalId,
            deposit,
            lockPeriod,
            advancedDeposit
        );

        // submit vote
        _getAgora().submitVote(proposalId, msg.sender, uint128(voteWeight), value);
    }

    function finalizeProposal(bytes32 proposalId) external override onlyMember {
        IAgora agora = _getAgora();

        require(
            agora.getProposalStatus(proposalId) == IAgora.ProposalStatus.TO_FINALIZE,
            "Voting -> Agora: proposal cannot be finalized"
        );

        IAgora.VoteResult voteResult = agora.getVoteResult(proposalId);

        if (voteResult == IAgora.VoteResult.ACCEPTED) {
            _executeProposal(proposalId);
        }

        agora.finalizeProposal(proposalId, msg.sender, voteResult);
    }

    function changeVoteParam(VotingProposal memory votingProposal) internal {
        ProposedVoteParam memory _proposedVoteParam = votingProposal.voteParam;
        _getAgora().changeVoteParams(
            _proposedVoteParam.voteParamId,
            _proposedVoteParam.consensus,
            _proposedVoteParam.votingPeriod,
            _proposedVoteParam.gracePeriod,
            _proposedVoteParam.threshold,
            _proposedVoteParam.adminValidationPeriod
        );
    }

    function proposeNewVoteParams(
        string calldata name,
        IAgora.Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 minStartTime,
        uint32 adminValidationPeriod
    ) external onlyMember {
        bytes4 voteParamId = bytes4(keccak256(bytes(name)));
        IAgora agora = _getAgora();
        require(
            agora.getVoteParams(voteParamId).votingPeriod == 0,
            "Voting: cannot replace vote params"
        );

        ProposedVoteParam memory _voteParam = ProposedVoteParam(
            voteParamId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
        Consultation memory emptyConsultation;

        VotingProposal memory _proposal = VotingProposal(
            ProposalType.VOTE_PARAMS,
            emptyConsultation,
            _voteParam
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(_proposal)));

        agora.submitProposal(slotId, proposalId, false, VOTE_STANDARD, minStartTime, msg.sender);
        _votingProposals[proposalId] = _proposal;
    }

    function proposeConsultation(
        string calldata title,
        string calldata description,
        uint32 minStartTime
    ) external onlyMember {
        Consultation memory _consultation = Consultation(title, description, msg.sender);
        ProposedVoteParam memory _emptyVoteParam;

        VotingProposal memory _proposal = VotingProposal(
            ProposalType.CONSULTATION,
            _consultation,
            _emptyVoteParam
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(_proposal)));
        _getAgora().submitProposal(
            slotId,
            proposalId,
            true,
            VOTE_STANDARD,
            minStartTime,
            msg.sender
        );
        _votingProposals[proposalId] = _proposal;
    }

    function withdrawAmount(uint128 amount) external onlyMember {
        _getBank().withdrawAmount(msg.sender, amount);
    }

    function advanceDeposit(uint128 amount) external onlyMember {
        _getBank().advancedDeposit(msg.sender, amount);
    }

    function addNewVoteParams(
        string memory name,
        IAgora.Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external onlyAdmin {
        bytes4 voteParamId = bytes4(keccak256(bytes(name)));
        _getAgora().changeVoteParams(
            voteParamId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
    }

    function removeVoteParams(bytes4 voteParamId) external onlyAdmin {
        _getAgora().changeVoteParams(voteParamId, IAgora.Consensus.NO_VOTE, 0, 0, 0, 0);
    }

    function validateProposal(bytes32 proposalId) external onlyAdmin {
        //
    }

    function getConsultation(bytes28 proposalId)
        external
        view
        returns (Consultation memory consultation)
    {
        consultation = _votingProposals[proposalId].consultation;
        require(consultation.initiater != address(0), "Voting: no consultation");
    }

    function getProposedVoteParam(bytes28 proposalId)
        external
        view
        returns (ProposedVoteParam memory _voteParam)
    {
        _voteParam = _votingProposals[proposalId].voteParam;
        require(_voteParam.voteParamId != Slot.EMPTY, "Voting: no vote params");
    }

    function _executeProposal(bytes32 proposalId) internal override {
        super._executeProposal(proposalId);

        VotingProposal memory votingProposal = _votingProposals[bytes28(proposalId << 32)];
        if (ProposalType.VOTE_PARAMS == votingProposal.proposalType) {
            changeVoteParam(votingProposal);
        }
        // TODO error should be handled here and other type of action function of type

        delete _votingProposals[bytes28(proposalId << 32)];
    }

    function _getBank() internal view returns (IBank) {
        return IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));
    }

    function _getAgora() internal view returns (IAgora) {
        return IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
    }
}
