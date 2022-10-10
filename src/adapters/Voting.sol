// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "../guards/SlotGuard.sol";
import "../extensions/IBank.sol";
import "../extensions/IAgora.sol";

contract Voting is SlotGuard {
    // should cache Bank & Agora ?
    struct Consultation {
        string title;
        string description;
    }

    mapping(bytes28 => Consultation) public proposals;

    constructor(address core) SlotGuard(core, Slot.VOTING) {}

    function submitVote(
        bytes32 proposalId,
        uint256 value,
        uint256 deposit,
        uint256 lockPeriod
    ) external onlyMember {
        IAgora agora = _getAgoraContract();
        IBank bank = _getBankContract();

        // get vote Weight
        uint256 voteWeight =
            bank.newCommitment(proposalId, msg.sender, deposit, lockPeriod);

        agora.submitVote(
            proposalId, msg.sender, uint128(voteWeight), value
        );
    }

    function processProposal(bytes4 slot, bytes28 proposalId)
        external
        onlyAdmin
    {
        IDaoCore(_core).processProposal(slot, proposalId);
    }

    function _getBankContract() internal view returns (IBank) {
        return IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));
    }

    function _getAgoraContract() internal view returns (IAgora) {
        return IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
    }
}
