// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../abstracts/ProposerAdapter.sol";
import "../interfaces/IBank.sol";
import "../interfaces/IAgora.sol";

contract Voting is ProposerAdapter {
    struct Consultation {
        string title;
        string description;
    }

    mapping(bytes28 => Consultation) public proposals;

    constructor(address core) Adapter(core, Slot.VOTING) {}

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
        uint96 deposit,
        uint32 lockPeriod,
        uint96 advanceDeposit
    ) external onlyMember {
        // get vote Weight
        uint96 voteWeight = _getBank().newCommitment(
            msg.sender,
            proposalId,
            deposit,
            lockPeriod,
            advanceDeposit
        );

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
