// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/utils/Counters.sol";

import "../interfaces/IProposerAdapter.sol";
import "./Adapter.sol";

abstract contract ProposerAdapter is Adapter, IProposerAdapter {
    using Counters for Counters.Counter;

    bool private _paused;
    Counters.Counter private _ongoingProposals;

    modifier paused() {
        require(!_paused, "Adapter: paused");
        _;
    }

    function finalizeProposal(bytes32 proposalId) external override onlyExtension(Slot.AGORA) {
        require(bytes4(proposalId) == slotId, "Adapter: wrong proposalId"); // is useful? will be too late at this time
        _ongoingProposals.decrement();
    }

    function ongoingProposals() external view override returns (uint256) {
        return _ongoingProposals.current();
    }

    function pauseAdapter() external onlyAdmin {
        _paused = !_paused;
    }

    function _newProposal() private paused {
        _ongoingProposals.increment();
    }
}
