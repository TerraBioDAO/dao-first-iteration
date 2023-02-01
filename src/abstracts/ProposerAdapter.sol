// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { ProposalState } from "../helpers/ProposalState.sol";
import { IProposerAdapter } from "../interfaces/IProposerAdapter.sol";
import { IAgora } from "../interfaces/IAgora.sol";
import { Adapter } from "./Adapter.sol";
import { Slot } from "../helpers/Slot.sol";

/**
 * @notice Extensions of abstract contract Adapters which implement
 * proposals submissions to Agora.
 *
 * @dev Allow contract to manage proposals counters, check vote result and
 * risk mitigation
 */

/**
 * @title Abstract contract to add functionalities for adapters
 * @dev Allow admin to pause or desactive the adapter, counters of
 * proposals are also implemented to maintain datas into the contract,
 * archive it and then delete it.
 */
abstract contract ProposerAdapter is Adapter, IProposerAdapter {
    using ProposalState for ProposalState.State;

    ProposalState.State private _state;

    modifier paused() {
        require(!_state.paused(), "Adapter: paused");
        _;
    }

    /*//////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Called to finalize and archive a proposal
     * @dev trigger {_executeProposal} if accepted, this latter
     * function must be overrided in adapter implementation
     * with the logic of the adapter
     *
     * @param proposalId proposal to finalize
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
     * @notice Called by AGORA extension to delete an archive in this contract
     * @dev decrement the archive counter
     */
    function deleteArchive(bytes32) external virtual onlyExtension(Slot.AGORA) {
        // implement logic here
        _state.decrementArchive();
    }

    /**
     * @notice Allow an admin to pause and unpause the adapter
     * @dev inverse the current pause state
     */
    function pauseToggleAdapter() external onlyAdmin {
        _state.pauseToggle();
    }

    /**
     * @notice Desactivate the adapter, admin-only
     * @dev CAUTION this function is not reversible,
     * only triggerable when there is no ongoing proposal
     */
    function desactive() external onlyAdmin {
        require(_state.currentOngoing() == 0, "Proposer: ongoing proposals");
        _state.desactivate();
    }

    /*//////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////*/

    /// @return amount of ongoing proposals
    function ongoingProposals() external view returns (uint256) {
        return _state.currentOngoing();
    }

    /// @return amount of archived proposals
    function archivedProposals() external view returns (uint256) {
        return _state.currentArchive();
    }

    /// @return true if the adapter is paused
    function isPaused() external view returns (bool) {
        return _state.paused();
    }

    /// @return true if the proposal is desactived
    function isDesactived() external view returns (bool) {
        return _state.desactived();
    }

    /*//////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @dev Decrement ongoing proposal and increment
     * archived proposal counter
     */
    function _archiveProposal() internal paused {
        _state.decrementOngoing();
        _state.incrementArchive();
    }

    /**
     * @dev Called after a proposal is submitted to Agora, increase
     * the proposal counter, check if the adapter is not paused or
     * desactived.
     */
    function _newProposal() internal paused {
        require(!_state.desactived(), "Proposer: adapter desactived");
        _state.incrementOngoing();
    }

    /**
     * @dev Check the vote result of a proposal.
     * The function return the vote result and the interface of Agora
     *
     * NOTE This function could be transformed into a modifier which act
     * before and after the function {Adapter::finalizeProposal} as this
     * latter must call {Agora::finalizeProposal} then.
     *
     * @param proposalId proposal to check
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
     * @dev Function used as a hook to implement the logic
     * following an accepted proposal.
     * @param proposalId executed proposal
     */
    function _executeProposal(bytes32 proposalId) internal virtual {}

    /**
     * @param proposalId proposal to read
     * @return proposal hash without the slotID
     */
    function _readProposalId(bytes32 proposalId) internal pure returns (bytes28) {
        return bytes28(proposalId << 32);
    }
}
