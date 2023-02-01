// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { ProposerAdapter, Adapter, Slot } from "../abstracts/ProposerAdapter.sol";
import { IBank } from "../interfaces/IBank.sol";
import { IAgora } from "../interfaces/IAgora.sol";

/**
 * @title Contract managing votes, namely submissions, parameters and token commitments
 * @notice Users can submit votes, vote parameters proposals, consultation and
 * also deposit and withdraw from the Bank
 */
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

    /// @dev track proposals by their hash
    mapping(bytes28 => VotingProposal) private _votingProposals;

    /// @param core address of DaoCore
    constructor(address core) Adapter(core, Slot.VOTING) {}

    /*//////////////////////////////////////////////////////////
                            PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Users can submit vote to any existing proposals
     * @dev When vote is submitted the vote weight is calculated with
     * the deposit of token and locking period in the Bank.
     *
     * @param proposalId proposal to vote
     * @param value descision for the vote
     * @param deposit amount of token deposited for this proposal
     * @param lockPeriod token locking period duration
     * @param advancedDeposit amount of token to fill user's account
     */
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

    /**
     * @notice Users can submit a proposal for adding new vote parameters
     * @dev `name` is hash to create a voteID (bytes4), checking vote parameters
     * is done in Agora
     *
     * @param name name of the vote parameter (then hashed)
     * @param consensus consensus type
     * @param votingPeriod voting period
     * @param gracePeriod grace period after the vote
     * @param threshold acceptation threshold
     * @param minStartTime timestamp when the proposal should start
     * @param adminValidationPeriod period of grace before the vote
     */
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

    /**
     * @notice Users can submit consultation (proposal without on-chain execution)
     * @dev Consultation should then be implemented off-chain
     * NOTE Only a string or an hash of IPFS shoudl be stored on-chain
     *
     * @param title name of the consultation
     * @param description description of the consultation
     * @param minStartTime timestamp when the proposal should start
     */
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

    /**
     * @notice Allow member to withdraw available $TBIO balance in the Bank
     *
     * @param amount amount of token to withdraw
     */
    function withdrawAmount(uint128 amount) external onlyMember {
        IBank(_slotAddress(Slot.BANK)).withdrawAmount(msg.sender, amount);
    }

    /**
     * @notice Allow member to deposit $TBIO into their account in Bank
     *
     * @param amount amount of token to deposit
     */
    function advanceDeposit(uint128 amount) external onlyMember {
        IBank(_slotAddress(Slot.BANK)).advancedDeposit(msg.sender, amount);
    }

    /**
     * @notice Allow member to request an archive removal
     * @dev The archive should be enough old to be deleted
     *
     * @param proposalId archive to delete
     */
    function requestDeleteArchive(bytes32 proposalId) external onlyMember {
        IAgora(_slotAddress(Slot.AGORA)).deleteArchive(proposalId, msg.sender);
    }

    /**
     * @notice Allow admin to add a new vote parameter
     *
     * @param name name of the vote parameter (then hashed)
     * @param consensus consensus type
     * @param votingPeriod voting period
     * @param gracePeriod grace period after the vote
     * @param threshold acceptation threshold
     * @param adminValidationPeriod period of grace before the vote
     */
    function addNewVoteParams(
        string memory name,
        IAgora.Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external onlyAdmin {
        bytes4 voteParamId = bytes4(keccak256(bytes(name)));

        IAgora(_slotAddress(Slot.AGORA)).changeVoteParam(
            true, // isToAdd
            voteParamId,
            consensus,
            votingPeriod,
            gracePeriod,
            threshold,
            adminValidationPeriod
        );
    }

    /**
     * @notice Allow admin to remove a vote parameter
     *
     * @param voteParamId voteID to remove
     */
    function removeVoteParams(bytes4 voteParamId) external onlyAdmin {
        IAgora(_slotAddress(Slot.AGORA)).changeVoteParam(
            false,
            voteParamId,
            IAgora.Consensus.UNINITIATED,
            0,
            0,
            0,
            0
        );
    }

    /**
     * @notice Validation of a proposal, admin-only
     * @dev Not implemented
     *
     * @param proposalId proposal to validate
     */
    function validateProposal(bytes32 proposalId) external onlyAdmin {
        //
    }

    /*//////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Get consultation details
     * @param proposalId proposal to check
     * @return consultation {Consultation} struct
     */
    function getConsultation(bytes28 proposalId)
        external
        view
        returns (Consultation memory consultation)
    {
        consultation = _votingProposals[proposalId].consultation;
        require(consultation.initiater != address(0), "Voting: no consultation");
    }

    /**
     * @notice Get details of a proposed vote parameters
     * @param proposalId proposal to check
     * @return _voteParam {ProposedVoteParam} struct
     */
    function getProposedVoteParam(bytes28 proposalId)
        external
        view
        returns (ProposedVoteParam memory _voteParam)
    {
        _voteParam = _votingProposals[proposalId].voteParam;
        require(_voteParam.voteParamId != Slot.EMPTY, "Voting: no vote params");
    }

    /*//////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to add parameter
     * @param votingProposal {VotingProposal} struct
     */
    function _addVoteParam(VotingProposal memory votingProposal) internal {
        ProposedVoteParam memory _proposedVoteParam = votingProposal.voteParam;
        IAgora(_slotAddress(Slot.AGORA)).changeVoteParam(
            true,
            _proposedVoteParam.voteParamId,
            _proposedVoteParam.consensus,
            _proposedVoteParam.votingPeriod,
            _proposedVoteParam.gracePeriod,
            _proposedVoteParam.threshold,
            _proposedVoteParam.adminValidationPeriod
        );
    }

    /**
     * @dev Implementation of {_executeProposal}
     *
     * @param proposalId transaction request to execute
     */
    function _executeProposal(bytes32 proposalId) internal override {
        VotingProposal memory votingProposal = _votingProposals[_readProposalId(proposalId)];
        if (ProposalType.VOTE_PARAMS == votingProposal.proposalType) {
            _addVoteParam(votingProposal);
        }
        // TODO error should be handled here and other type of action function of type

        // => do nothing if consultation is accepted or add flag in struct Consultation
    }
}
