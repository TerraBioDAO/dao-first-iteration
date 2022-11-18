// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin-contracts/utils/Counters.sol";

import "../interfaces/IProposerAdapter.sol";
import "../interfaces/IAgora.sol";
import "./Adapter.sol";

/**
 * @notice Extensions of abstract contract Adapters which implement
 * a proposal submission to Agora.
 *
 * @dev Allow contract to manage proposals counters, check vote result and
 * risk mitigation
 */
abstract contract ProposerAdapter is Adapter, IProposerAdapter {
    using Counters for Counters.Counter;

    /// @dev consider using Pausable.sol from OZ
    bool private _paused;

    Counters.Counter private _ongoingProposals;

    modifier paused() {
        require(!_paused, "Adapter: paused");
        _;
    }

    /**
     * @notice allow an admin to pause and unpause the adapter
     */
    function pauseAdapter() external onlyAdmin {
        _paused = !_paused;
    }

    /**
     * @notice getter for current numbers proposal
     */
    function ongoingProposals() external view override returns (uint256) {
        return _ongoingProposals.current();
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    /**
     * @notice function to override, manage to decrement proposal
     * counter on proposal execution
     *
     * NOTE This should be called anytime a proposal is finalized,
     * not matter the vote result, consider changing the name for more
     * lisibility
     */
    function _executeProposal(bytes32 proposalId) internal virtual {
        require(bytes4(proposalId) == slotId, "Adapter: wrong proposalId"); // is useful? will be too late at this time
        _ongoingProposals.decrement();
    }

    /**
     * @notice called after a proposal is submitted to Agora.
     * @dev will increase the proposal counter and check if the
     * adapter has not been paused.
     */
    function _newProposal() internal paused {
        _ongoingProposals.increment();
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
        returns (IAgora.VoteResult accepted, IAgora agora)
    {
        agora = IAgora(_slotAddress(Slot.AGORA));
        require(
            agora.getProposalStatus(proposalId) == IAgora.ProposalStatus.TO_FINALIZE,
            "Agora: proposal cannot be finalized"
        );

        accepted = agora.getVoteResult(proposalId);
    }
}
