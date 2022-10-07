// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "../guards/SlotGuard.sol";
import "../extensions/Bank.sol";
import "../adapters/Voting.sol";

/**
 * @notice Financing submit and process proposals to finance projects.
 * Financing is only in TBIO
 */
contract Financing is SlotGuard {
    struct Proposal {
        address applicant; // the proposal applicant address
        uint256 amount; // the amount requested for funding
    }

    mapping(bytes28 => Proposal) public proposals;

    constructor(address core) SlotGuard(core, Slot.FINANCING) {}

    /**
     * @notice Creates financing proposal.
     * @dev Requested amount must be greater than zero.
     * @dev Only members of the DAO can create a financing proposal.
     * @param proposal The Proposal data
     */
    function submitProposal(Proposal memory proposal)
        external
        onlyProposer
    {
        require(proposal.amount > 0, "invalid requested amount");

        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        IDaoCore(_core).submitProposal(
            bytes32(bytes.concat(Slot.FINANCING, proposalId)),
            msg.sender,
            dao.getSlotContractAddress(Slot.VOTING)
        );
    }

    /**
     * @notice Processing a financing proposal to grant the requested funds.
     * @dev Only proposals that were not processed are accepted.
     * @dev Only proposals that passed can get processed and have the funds released.
     * @param dao The DAO Address.
     * @param proposalId The proposal id.
     */
    function processProposal(bytes32 proposalId) external onlyCore {
        Proposal memory proposal = proposals[bytes28(proposalId << 32)];
        IDaoCore dao = IDaoCore(_core);
        Voting voting = Voting(dao.getSlotContractAddress(Slot.VOTING));

        require(address(voting) != address(0), "adapter not found");
        // Check proposal status
        require(
            voting.voteResult(dao, proposalId) == Voting.VotingState.PASS, // Agora ?
            "proposal needs to pass"
        );

        dao.processProposal(proposalId);
        Bank bank = Bank(dao.getSlotContractAddress(Slot.BANK));

        bank.executeFinancingProposal(proposalId, proposal.applicant, proposal.token, proposal.amount);

        delete proposals[bytes28(proposalId << 32)];
    }
}
