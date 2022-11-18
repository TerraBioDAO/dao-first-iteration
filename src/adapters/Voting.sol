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

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
    function submitVote(
        bytes32 proposalId,
        uint256 value,
        uint96 deposit,
        uint32 lockPeriod,
        uint96 advancedDeposit
    ) external onlyMember {
        // get vote Weight
        uint96 voteWeight = IBank(_slotAddress(Slot.BANK)).newCommitment(
            msg.sender,
            proposalId,
            deposit,
            lockPeriod,
            advancedDeposit
        );

        // submit vote
        IAgora(_slotAddress(Slot.AGORA)).submitVote(
            proposalId,
            msg.sender,
            uint128(voteWeight),
            value
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
        IAgora agora = IAgora(_slotAddress(Slot.AGORA));
        require(
            agora.getVoteParams(voteParamId).votingPeriod == 0,
            "Voting: cannot replace vote params"
        );

        // proposal construction
        ProposedVoteParam memory voteParam_ = ProposedVoteParam(
            voteParamId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
        Consultation memory emptyConsultation;
        VotingProposal memory proposal_ = VotingProposal(
            ProposalType.VOTE_PARAMS,
            emptyConsultation,
            voteParam_
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal_)));

        _newProposal();
        _votingProposals[proposalId] = proposal_;

        agora.submitProposal(slotId, proposalId, false, VOTE_STANDARD, minStartTime, msg.sender);
    }

    function proposeConsultation(
        string calldata title,
        string calldata description,
        uint32 minStartTime
    ) external onlyMember {
        Consultation memory consultation_ = Consultation(title, description, msg.sender);
        ProposedVoteParam memory emptyVoteParam;

        VotingProposal memory proposal_ = VotingProposal(
            ProposalType.CONSULTATION,
            consultation_,
            emptyVoteParam
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal_)));

        _newProposal();
        _votingProposals[proposalId] = proposal_;

        IAgora(_slotAddress(Slot.AGORA)).submitProposal(
            slotId,
            proposalId,
            true,
            VOTE_STANDARD,
            minStartTime,
            msg.sender
        );
    }

    function withdrawAmount(uint128 amount) external onlyMember {
        IBank(_slotAddress(Slot.BANK)).withdrawAmount(msg.sender, amount);
    }

    function advanceDeposit(uint128 amount) external onlyMember {
        IBank(_slotAddress(Slot.BANK)).advancedDeposit(msg.sender, amount);
    }

    function requestDeleteArchive(bytes32 proposalId) external onlyMember {
        IAgora(_slotAddress(Slot.AGORA)).deleteArchive(proposalId, msg.sender);
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

        IAgora(_slotAddress(Slot.AGORA)).changeVoteParams(
            voteParamId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
    }

    function removeVoteParams(bytes4 voteParamId) external onlyAdmin {
        IAgora(_slotAddress(Slot.AGORA)).changeVoteParams(
            voteParamId,
            IAgora.Consensus.NO_VOTE,
            0,
            0,
            0,
            0
        );
    }

    function validateProposal(bytes32 proposalId) external onlyAdmin {
        //
    }

    /* //////////////////////////
                GETTERS
    ////////////////////////// */

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

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    function _changeVoteParam(VotingProposal memory votingProposal) internal {
        ProposedVoteParam memory _proposedVoteParam = votingProposal.voteParam;
        IAgora(_slotAddress(Slot.AGORA)).changeVoteParams(
            _proposedVoteParam.voteParamId,
            _proposedVoteParam.consensus,
            _proposedVoteParam.votingPeriod,
            _proposedVoteParam.gracePeriod,
            _proposedVoteParam.threshold,
            _proposedVoteParam.adminValidationPeriod
        );
    }

    function _executeProposal(bytes32 proposalId) internal override {
        VotingProposal memory votingProposal = _votingProposals[_readProposalId(proposalId)];
        if (ProposalType.VOTE_PARAMS == votingProposal.proposalType) {
            _changeVoteParam(votingProposal);
        }
        // TODO error should be handled here and other type of action function of type

        // => do nothing if consultation is accepted or add flag in struct Consultation
    }
}
