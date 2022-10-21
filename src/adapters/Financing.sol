// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../abstracts/ProposerAdapter.sol";
import "../interfaces/IBank.sol";
import "../interfaces/IAgora.sol";
import "../adapters/Voting.sol";

/**
 * @notice Financing submit and process proposals to finance projects.
 * Financing is only in TBIO
 */
contract Financing is ProposerAdapter {
    struct Proposal {
        address applicant; // the proposal applicant address
        uint256 amount; // the amount requested for funding
    }

    mapping(bytes28 => Proposal) private proposals;

    constructor(address core) Adapter(core, Slot.FINANCING) {}

    /**
     * @notice Creates financing proposal.
     * @dev Requested amount must be greater than zero.
     * @dev Only members of the DAO can create a financing proposal.
     * @param proposal The Proposal data
     */
    function submitProposal(Proposal memory proposal) external onlyProposer {
        require(proposal.amount > 0, "Financing: invalid requested amount");

        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        proposals[proposalId] = proposal;

        IAgora agora = IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
        IBank bank = IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));

        bank.setFinancingProposalData(
            bytes32(bytes.concat(Slot.FINANCING, proposalId)),
            proposal.amount
        );

        // startime = 0 => startime = timestamp
        // voteID in args
        // admin validation depends on sender role
        agora.submitProposal(Slot.FINANCING, proposalId, true, true, bytes4(0), 0, msg.sender);
    }

    /**
     * @notice Processing a financing proposal to grant the requested funds.
     * @dev Only proposals that were not processed are accepted.
     * @dev Only proposals that passed can get processed and have the funds released.
     * @param proposalId The proposal id.
     */
    function processProposal(bytes32 proposalId) external onlyExtension(Slot.AGORA) returns (bool) {
        Proposal memory proposal = proposals[bytes28(proposalId << 32)];

        IDaoCore dao = IDaoCore(_core);
        IBank bank = IBank(dao.getSlotContractAddr(Slot.BANK));

        delete proposals[bytes28(proposalId << 32)];

        return bank.executeFinancingProposal(proposalId, proposal.applicant, proposal.amount);
    }
}
