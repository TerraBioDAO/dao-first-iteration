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
        bytes4 voteId;
        IAgora.Consensus consensus;
        uint32 votingPeriod;
        uint32 gracePeriod;
        uint32 threshold;
        uint32 adminValidationPeriod;
    }

    struct Proposal {
        ProposalType proposalType;
        Consultation consultation;
        ProposedVoteParam voteParam;
    }

    mapping(bytes28 => Proposal) private _proposals;

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

    function executeProposal(bytes32 proposalId) public override {
        super.executeProposal(proposalId);

        ProposedVoteParam memory _voteParam = _proposals[bytes28(proposalId << 32)].voteParam;
        _getAgora().changeVoteParams(
            _voteParam.voteId,
            _voteParam.consensus,
            _voteParam.votingPeriod,
            _voteParam.gracePeriod,
            _voteParam.threshold,
            _voteParam.adminValidationPeriod
        );
        delete _proposals[bytes28(proposalId << 32)];
    }

    function finalizeProposal(bytes32 proposalId) external onlyMember {
        _getAgora().finalizeProposal(proposalId, msg.sender);
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
        bytes4 voteId = bytes4(keccak256(bytes(name)));
        IAgora agora = _getAgora();
        require(
            agora.getVoteParams(voteId).votingPeriod == 0,
            "Voting: cannot replace vote params"
        );

        ProposedVoteParam memory _voteParam = ProposedVoteParam(
            voteId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
        Consultation memory emptyConsultation;

        Proposal memory _proposal = Proposal(
            ProposalType.VOTE_PARAMS,
            emptyConsultation,
            _voteParam
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(_proposal)));

        agora.submitProposal(
            slotId,
            proposalId,
            false,
            true,
            Slot.VOTE_STANDARD,
            minStartTime,
            msg.sender
        );
        _proposals[proposalId] = _proposal;
    }

    function proposeConsultation(
        string calldata title,
        string calldata description,
        uint32 minStartTime
    ) external onlyMember {
        Consultation memory _consultation = Consultation(title, description, msg.sender);
        ProposedVoteParam memory _emptyVoteParam;

        Proposal memory _proposal = Proposal(
            ProposalType.CONSULTATION,
            _consultation,
            _emptyVoteParam
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(_proposal)));
        _getAgora().submitProposal(
            slotId,
            proposalId,
            true,
            false,
            Slot.VOTE_STANDARD,
            minStartTime,
            msg.sender
        );
        _proposals[proposalId] = _proposal;
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
        bytes4 voteId = bytes4(keccak256(bytes(name)));
        _getAgora().changeVoteParams(
            voteId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
    }

    function removeVoteParams(bytes4 voteId) external onlyAdmin {
        _getAgora().changeVoteParams(voteId, IAgora.Consensus.NO_VOTE, 0, 0, 0, 0);
    }

    function getConsultation(bytes28 proposalId)
        external
        view
        returns (Consultation memory consultation)
    {
        consultation = _proposals[proposalId].consultation;
        require(consultation.initiater != address(0), "Voting: no consultation");
    }

    function getProposedVoteParam(bytes28 proposalId)
        external
        view
        returns (ProposedVoteParam memory _voteParam)
    {
        _voteParam = _proposals[proposalId].voteParam;
        require(_voteParam.voteId != Slot.EMPTY, "Voting: no vote params");
    }

    function _getBank() internal view returns (IBank) {
        return IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));
    }

    function _getAgora() internal view returns (IAgora) {
        return IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
    }
}
