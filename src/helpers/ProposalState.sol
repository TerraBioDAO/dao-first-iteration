// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

/**
 * @notice Library which mix up Counters.sol and Pausable.sol from
 * OpenZeppelin.
 *
 * @dev it define and provide utils to manage the state of an adapter
 */

library ProposalState {
    error DecrementOverflow();

    /**
     * @notice overflow is not checked, as the maximum number is
     * 4_294_967_295, only underflow is checked
     */
    struct State {
        bool isPaused;
        bool isDesactived;
        uint32 ongoingProposal;
        uint32 archivedProposal;
    }

    /* //////////////////////////
                FLAGS
    ////////////////////////// */
    function desactived(State storage state) internal view returns (bool) {
        return state.isDesactived;
    }

    function paused(State storage state) internal view returns (bool) {
        return state.isPaused;
    }

    function pause(State storage state) internal {
        state.isPaused = true;
    }

    function unpause(State storage state) internal {
        state.isPaused = false;
    }

    function desactivate(State storage state) internal {
        state.isDesactived = true;
    }

    /* //////////////////////////
            COUNTERS
    ////////////////////////// */

    function currentOngoing(State storage state) internal view returns (uint256) {
        return state.ongoingProposal;
    }

    function currentArchive(State storage state) internal view returns (uint256) {
        return state.archivedProposal;
    }

    function incrementOngoing(State storage state) internal {
        unchecked {
            ++state.ongoingProposal;
        }
    }

    function decrementOngoing(State storage state) internal {
        uint256 value = state.ongoingProposal;
        if (value == 0) revert DecrementOverflow();
        unchecked {
            --state.ongoingProposal;
        }
    }

    function incrementArchive(State storage state) internal {
        unchecked {
            ++state.archivedProposal;
        }
    }

    function decrementArchive(State storage state) internal {
        uint256 value = state.archivedProposal;
        if (value == 0) revert DecrementOverflow();
        unchecked {
            --state.archivedProposal;
        }
    }
}
