// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/Extension.sol";
import "../helpers/Constants.sol";
import "../interfaces/IAgora.sol";
import "../interfaces/IProposerAdapter.sol";

/**
 * @notice contract which store votes parameters, vote result,
 * proposals and their status
 */

contract Agora is Extension, IAgora, Constants {
    using Slot for bytes28;

    struct Archive {
        uint32 archivedAt;
        address dataAddr;
    }

    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes4 => VoteParam) private _voteParams;
    mapping(bytes32 => mapping(address => bool)) private _haveVoted;
    mapping(bytes32 => Archive) private _archives;

    constructor(address core) Extension(core, Slot.AGORA) {
        _addVoteParam(VOTE_STANDARD, Consensus.TOKEN, 7 days, 3 days, 8000, 7 days);
    }

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
    function submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) external onlyAdapter(Slot.VOTING) {
        _submitVote(proposalId, voter, voteWeight, value);
    }

    function submitProposal(
        bytes4 slot,
        bytes28 adapterProposalId,
        bool adminApproved,
        bytes4 voteParamId,
        uint32 minStartTime,
        address initiater
    ) external onlyAdapter(slot) {
        bytes32 proposalId = adapterProposalId.concatWithSlot(slot);
        Proposal memory proposal_ = _proposals[proposalId];
        require(!proposal_.active, "Agora: proposal already exist");

        require(_voteParams[voteParamId].votingPeriod > 0, "Agora: unknown vote params");

        uint32 timestamp = uint32(block.timestamp);

        if (minStartTime == 0) minStartTime = timestamp;
        require(minStartTime >= timestamp, "Agora: wrong starting time");

        proposal_.active = true;
        proposal_.adminApproved = adminApproved;
        proposal_.createdAt = timestamp;
        proposal_.minStartTime = minStartTime;
        proposal_.initiater = initiater;
        proposal_.voteParamId = voteParamId;

        _proposals[proposalId] = proposal_;
        ++_voteParams[voteParamId].usesCount;

        emit ProposalSubmitted(slot, initiater, voteParamId, proposalId);
    }

    /**
     * @notice function used to flag that a proposal hase been
     * procedeed. Proposal are still in the storage of the contract.
     * @dev can be called by any adapter, allowing to implement restriction
     * on it if needed.
     *
     * TODO add logic to delete proposal once the corresponding the
     * maximal locking period is reached (< 1 year)
     */
    function finalizeProposal(
        bytes32 proposalId,
        address finalizer,
        bool accepted
    ) external onlyAdapter(bytes4(proposalId)) {
        _proposals[proposalId].proceeded = true;
        _archives[proposalId] = Archive(uint32(block.timestamp), msg.sender);
        emit ProposalFinalized(proposalId, finalizer, accepted);
    }

    /**
     * @notice delete archive (if more than one year of existance)
     * in Agora and then datas in the Adapter
     *
     * NOTE This function could be called by another adapter, like
     * an adapter related to reputation and rewards, the second argument
     * is for a future utilisation of the rewarding users for maintaining
     * the DAO. BTW this function could be in another extensions
     */
    function deleteArchive(bytes32 proposalId, address) external onlyAdapter(Slot.VOTING) {
        Archive memory archive_ = _archives[proposalId];
        require(archive_.archivedAt > 0, "Agora: not an archive");
        require(block.timestamp >= archive_.archivedAt + 365 days, "Agora: not archivable");
        IProposerAdapter(archive_.dataAddr).deleteArchive(proposalId);
        delete _archives[proposalId];

        // reward user here
    }

    /**
     * @notice to change vote parameters
     * @dev can be called by Voting adapter only
     * @param isToAdd : To ADD or REMOVE parameters
     * @param consensus : vote consensus
     * @param votingPeriod : voting period
     * @param gracePeriod : grace period
     * @param threshold : threshold from which the vote is validated(in per ten thousand i.e. percent cents)
     * @param adminValidationPeriod : admin validation period
     * Requirements:
     *  - can be called by Voting adapter only
     */
    function changeVoteParam(
        bool isToAdd,
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) external onlyAdapter(Slot.VOTING) {
        if (isToAdd) {
            _addVoteParam(
                voteParamId,
                consensus,
                votingPeriod,
                gracePeriod,
                threshold,
                adminValidationPeriod
            );
            return;
        }

        _removeVoteParam(voteParamId);
    }

    function validateProposal(bytes32 proposalId) external onlyAdapter(Slot.VOTING) {
        require(
            _evaluateProposalStatus(proposalId) == ProposalStatus.VALIDATION,
            "Agora: no validation required"
        );
        Proposal memory proposal_ = _proposals[proposalId];
        _proposals[proposalId].adminApproved = true;

        // postpone the `minStartTime` to now if passed
        uint256 timestamp = block.timestamp;
        if (proposal_.minStartTime < timestamp) {
            proposal_.minStartTime = uint32(timestamp);
        }
    }

    function suspendProposal(bytes32 proposalId) external onlyAdapter(Slot.VOTING) {
        ProposalStatus status = _evaluateProposalStatus(proposalId);
        require(
            status == ProposalStatus.STANDBY ||
                status == ProposalStatus.VALIDATION ||
                status == ProposalStatus.ONGOING ||
                status == ProposalStatus.CLOSED,
            "Agora: cannot suspend the proposal"
        );

        if (status == ProposalStatus.ONGOING) {
            _proposals[proposalId].suspendedAt = uint32(block.timestamp);
        } else if (status == ProposalStatus.CLOSED) {
            // flag when the proposal is suspended
            _proposals[proposalId].suspendedAt = 1;
        }
        _proposals[proposalId].suspended = true;
    }

    function unsuspendProposal(bytes32 proposalId) external onlyAdapter(Slot.VOTING) {
        Proposal memory proposal_ = _proposals[proposalId];
        require(proposal_.suspended, "Agora: proposal not suspended");
        uint256 timestamp = block.timestamp;

        proposal_.adminApproved = true;
        proposal_.suspended = false;
        if (proposal_.suspendedAt == 0) {
            // only if suspended in STANDBY or VALIDATION
            proposal_.minStartTime = uint32(timestamp);
        } else if (proposal_.suspendedAt > 1) {
            // postpone voting period if suspended in ONGOING
            proposal_.shiftedTime += uint32(timestamp - proposal_.suspendedAt);
        }

        _proposals[proposalId] = proposal_;
    }

    /* //////////////////////////
                GETTERS
    ////////////////////////// */
    function getProposalStatus(bytes32 proposalId) external view returns (ProposalStatus) {
        return _evaluateProposalStatus(proposalId);
    }

    function getVoteResult(bytes32 proposalId) external view returns (bool accepted) {
        return _calculateVoteResult(proposalId);
    }

    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    function getVoteParams(bytes4 voteParamId) external view returns (VoteParam memory) {
        return _voteParams[voteParamId];
    }

    function hasVoted(bytes32 proposalId, address voter) external view returns (bool) {
        return _haveVoted[proposalId][voter];
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    /**
     * @dev internal
     * @param threshold : threshold from which the vote is validated(in per ten thousand i.e. percent cents)
     */
    function _addVoteParam(
        bytes4 voteParamId,
        Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold,
        uint32 adminValidationPeriod
    ) internal {
        VoteParam memory voteParam_ = _voteParams[voteParamId];
        require(voteParam_.consensus == Consensus.UNINITIATED, "Agora: cannot replace params");

        require(consensus != Consensus.UNINITIATED, "Agora: bad consensus");
        require(votingPeriod > 0, "Agora: below min period");
        require(threshold <= 10000, "Agora: wrong threshold or below min value");

        voteParam_.consensus = consensus;
        voteParam_.votingPeriod = votingPeriod;
        voteParam_.gracePeriod = gracePeriod;
        voteParam_.threshold = threshold;
        voteParam_.adminValidationPeriod = adminValidationPeriod;

        _voteParams[voteParamId] = voteParam_;

        emit VoteParamsChanged(voteParamId, true);
    }

    /**
     * @dev internal
     * requirements :
     *  - vote parameters must not be in use.
     */
    function _removeVoteParam(bytes4 voteParamId) internal {
        uint256 usesCount = _voteParams[voteParamId].usesCount;
        require(usesCount == 0, "Agora: parameters still used");

        delete _voteParams[voteParamId];
        emit VoteParamsChanged(voteParamId, false);
    }

    function _submitVote(
        bytes32 proposalId,
        address voter,
        uint128 voteWeight,
        uint256 value
    ) internal {
        require(
            _evaluateProposalStatus(proposalId) == ProposalStatus.ONGOING,
            "Agora: outside voting period"
        );

        require(!_haveVoted[proposalId][voter], "Agora: proposal voted");
        _haveVoted[proposalId][voter] = true;

        Proposal memory proposal_ = _proposals[proposalId];

        if (_voteParams[proposal_.voteParamId].consensus == Consensus.MEMBER) {
            voteWeight = 1;
        }

        require(value <= 2, "Agora: neither (y), (n), (nota)");
        ++proposal_.score.memberVoted;
        if (value == 0) {
            proposal_.score.nbYes += voteWeight;
        } else if (value == 1) {
            proposal_.score.nbNo += voteWeight;
        } else {
            proposal_.score.nbNota += voteWeight;
        }

        _proposals[proposalId] = proposal_;
        emit MemberVoted(proposalId, voter, value, voteWeight);
    }

    function _calculateVoteResult(bytes32 proposalId) internal view returns (bool accepted) {
        Proposal memory proposal_ = _proposals[proposalId];
        Score memory score_ = proposal_.score;
        // how to integrate NOTA vote, should it be?
        uint256 totalVote = score_.nbYes + score_.nbNo;

        return
            totalVote != 0 &&
            (score_.nbYes * 10000) / totalVote >= _voteParams[proposal_.voteParamId].threshold;
    }

    function _evaluateProposalStatus(bytes32 proposalId) internal view returns (ProposalStatus) {
        Proposal memory proposal_ = _proposals[proposalId];
        VoteParam memory voteParam_ = _voteParams[proposal_.voteParamId];
        uint256 timestamp = block.timestamp;

        // proposal exist?
        if (!proposal_.active) {
            return ProposalStatus.UNKNOWN;
        }

        // is suspended?
        if (proposal_.suspended) {
            return ProposalStatus.SUSPENDED;
        }

        // is approved by admin?
        if (!proposal_.adminApproved) {
            uint256 endOfValidationPeriod = proposal_.createdAt + voteParam_.adminValidationPeriod;
            if (timestamp < endOfValidationPeriod) {
                return ProposalStatus.VALIDATION;
            } else {
                // virtualy postpone the `minStartTime`
                if (proposal_.minStartTime < endOfValidationPeriod) {
                    proposal_.minStartTime = uint32(endOfValidationPeriod);
                }
            }
        }

        // has started?
        if (timestamp < proposal_.minStartTime) {
            return ProposalStatus.STANDBY;
        }

        // is in voting period?
        if (timestamp < proposal_.minStartTime + proposal_.shiftedTime + voteParam_.votingPeriod) {
            return ProposalStatus.ONGOING;
        }

        // is in grace period?
        if (
            timestamp <
            proposal_.minStartTime +
                proposal_.shiftedTime +
                voteParam_.votingPeriod +
                voteParam_.gracePeriod
        ) {
            return ProposalStatus.CLOSED;
        }

        // is finalized
        if (!proposal_.proceeded) {
            return ProposalStatus.TO_FINALIZE;
        } else {
            return ProposalStatus.ARCHIVED;
        }
    }
}
