// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../helpers/ProposalState.sol";
import "../interfaces/IProposerAdapter.sol";
import "../interfaces/IAgora.sol";
import "./Adapter.sol";

/**
 * @notice Extensions of abstract contract Adapters which implement
 * proposals submissions to Agora.
 *
 * @dev Allow contract to manage proposals counters, check vote result and
 * risk mitigation
 */
abstract contract ProposerAdapter is Adapter, IProposerAdapter {
    using ProposalState for ProposalState.State;

    ProposalState.State private _state;

    modifier paused() {
        require(!_state.paused(), "Adapter: paused");
        _;
    }

    /**
     * @notice called to finalize and archive a proposal
     * {_executeProposal} if accepted, this latter
     * function must be overrided in adapter implementation
     * with the logic of the adapter
     *
     * NOTE This function shouldn't be overrided (virtual), but maybe
     * it would be an option
     */
    function finalizeProposal(bytes32 proposalId) external onlyMember {
        (bool accepted, IAgora agora) = _checkProposalResult(proposalId);

        if (accepted) {
            _executeProposal(proposalId);
        }

        _archiveProposal();
        agora.finalizeProposal(proposalId, msg.sender, accepted);
    }

    /**
     * @notice delete the archive after one year, Agora
     * store and do check before calling this function
     */
    function deleteArchive(bytes32) external virtual onlyExtension(Slot.AGORA) {
        // implement logic here
        _state.decrementArchive();
    }

    /**
     * @notice allow an admin to pause and unpause the adapter
     * @dev inverse the current pause state
     */
    function pauseToggleAdapter() external onlyAdmin {
        _state.pauseToggle();
    }

    /**
     * @notice desactivate the adapter
     * @dev CAUTION this function is not reversible,
     * only triggerable when there is no ongoing proposal
     */
    function desactive() external onlyAdmin {
        require(_state.currentOngoing() == 0, "Proposer: ongoing proposals");
        _state.desactivate();
    }

    /**
     * @notice getter for current numbers of ongoing proposal
     */
    function ongoingProposals() external view returns (uint256) {
        return _state.currentOngoing();
    }

    /**
     * @notice getter for current numbers of archived proposal
     */
    function archivedProposals() external view returns (uint256) {
        return _state.currentArchive();
    }

    function isPaused() external view returns (bool) {
        return _state.paused();
    }

    function isDesactived() external view returns (bool) {
        return _state.desactived();
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    /**
     * @notice decrement ongoing proposal and increment
     * archived proposal counter
     *
     * NOTE should be used when {Adapter::finalizeProposal}
     */
    function _archiveProposal() internal paused {
        _state.decrementOngoing();
        _state.incrementArchive();
    }

    /**
     * @notice called after a proposal is submitted to Agora.
     * @dev will increase the proposal counter, check if the
     * adapter has not been paused and check also if the
     * adapter has not been desactived
     */
    function _newProposal() internal paused {
        require(!_state.desactived(), "Proposer: adapter desactived");
        _state.incrementOngoing();
    }

    /**
     * @notice allow the proposal to check the vote result on
     * Agora, this function is only used (so far) when the adapter
     * needs to finalize a proposal
     *
     * @dev the function returns the {VoteResult} enum and the
     * {IAgora} interface to facilitate the result transmission to Agora
     *
     * NOTE This function could be transformed into a modifier which act
     * before and after the function {Adapter::finalizeProposal} as this
     * latter must call {Agora::finalizeProposal} then.
     */
    function _checkProposalResult(bytes32 proposalId)
        internal
        view
        returns (bool accepted, IAgora agora)
    {
        agora = IAgora(_slotAddress(Slot.AGORA));
        require(
            agora.getProposalStatus(proposalId) == IAgora.ProposalStatus.TO_FINALIZE,
            "Agora: proposal cannot be finalized"
        );

        accepted = agora.getVoteResult(proposalId);
    }

    /**
     * @notice this function is used as a hook to execute the
     * adapter logic when a proposal has been accepted.
     * @dev triggered by {finalizeProposal}
     */
    function _executeProposal(bytes32 proposalId) internal virtual {}

    function _readProposalId(bytes32 proposalId) internal pure returns (bytes28) {
        return bytes28(proposalId << 32);
    }
}
