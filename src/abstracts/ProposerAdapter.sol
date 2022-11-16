// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin-contracts/utils/Counters.sol";

import "../interfaces/IProposerAdapter.sol";
import "../interfaces/IAgora.sol";
import "./Adapter.sol";

abstract contract ProposerAdapter is Adapter, IProposerAdapter {
    using Counters for Counters.Counter;

    bool private _paused;
    Counters.Counter private _ongoingProposals;

    modifier paused() {
        require(!_paused, "Adapter: paused");
        _;
    }

    function pauseAdapter() external onlyAdmin {
        _paused = !_paused;
    }

    function ongoingProposals() external view override returns (uint256) {
        return _ongoingProposals.current();
    }

    function _executeProposal(bytes32 proposalId) internal virtual {
        require(bytes4(proposalId) == slotId, "Adapter: wrong proposalId"); // is useful? will be too late at this time
        _ongoingProposals.decrement();
    }

    function _newProposal() internal paused {
        _ongoingProposals.increment();
    }

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
