// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "../guards/SlotGuard.sol";
import "../extensions/IBank.sol";
import "../extensions/IAgora.sol";

contract Voting is SlotGuard {
    struct Consultation {
        string title;
        string description;
    }

    mapping(bytes28 => Consultation) public proposals;

    constructor(address core) SlotGuard(core, Slot.VOTING) {}

    function addNewVoteParams(
        string memory name,
        IAgora.Consensus consensus,
        uint32 votingPeriod,
        uint32 gracePeriod,
        uint32 threshold
    ) external onlyAdmin {
        bytes4 voteId = bytes4(keccak256(bytes(name)));
        _getAgora().changeVoteParams(voteId, consensus, votingPeriod, gracePeriod, threshold);
    }

    function removeVoteParams(bytes4 voteId) external onlyAdmin {
        _getAgora().changeVoteParams(voteId, IAgora.Consensus.NO_VOTE, 0, 0, 0);
    }

    function submitVote(
        bytes32 proposalId,
        uint256 value,
        uint256 deposit,
        uint256 lockPeriod,
        uint256 advanceDeposit
    ) external onlyMember {
        // get vote Weight
        uint256 voteWeight = _getBank().newCommitment(proposalId, msg.sender, deposit, lockPeriod);

        if (advanceDeposit > 0) {
            // bank.advanceDeposit
        }

        _getAgora().submitVote(proposalId, msg.sender, uint128(voteWeight), value);
    }

    function finalizeProposal(bytes4 slot, bytes28 proposalId) external onlyMember {
        bytes32 proposalId = bytes32(bytes.concat(slot, proposalId));
        _getAgora().finalizeProposal(proposalId, msg.sender);
    }

    function _getBank() internal view returns (IBank) {
        return IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));
    }

    function _getAgora() internal view returns (IAgora) {
        return IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
    }
}
