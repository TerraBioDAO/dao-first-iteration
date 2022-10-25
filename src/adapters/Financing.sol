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
     * @notice Creates financing proposal. Only PROPOSER role can create a financing proposal.
     * @param voteId vote parameters id
     * @param amount of the proposal
     * @param applicant of the proposal
     * requirements :
     * - Only PROPOSER role can create a financing proposal.
     * - Requested amount must be greater than zero.
     */
    function submitProposal(
        bytes4 voteId,
        uint256 amount,
        address applicant
    ) external onlyProposer {
        require(amount > 0, "Financing: invalid requested amount");
        Proposal memory proposal = Proposal(applicant, amount);

        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        proposals[proposalId] = proposal;

        IAgora agora = IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
        IBank bank = IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));

        // Assume that Vault is TREASURY or ask vaultId as parameter ?
        // TREASURY must have TBIO listed as available token
        // Assume that Token is TBIO

        bank.vaultCommit(Slot.TREASURY, bank.terraBioToken(), applicant, uint128(amount));

        // startime = 0 => startime = timestamp
        // admin validation depends on sender role
        agora.submitProposal(Slot.FINANCING, proposalId, true, true, voteId, 0, msg.sender);
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

        // Assume that Vault is TREASURY or ask vaultId as parameter ?
        // Assume token is TBio
        return
            bank.vaultTransfer(
                Slot.TREASURY,
                bank.terraBioToken(),
                proposal.applicant,
                uint128(proposal.amount)
            );
    }

    /**
     * @notice Create a vault
     * @dev Only admin can create a Vault.
     * @param vaultId vault id
     * @param tokenList array of token addresses
     */
    function createVault(bytes4 vaultId, address[] memory tokenList) external onlyAdmin {
        IDaoCore dao = IDaoCore(_core);
        IBank bank = IBank(dao.getSlotContractAddr(Slot.BANK));
        bank.createVault(vaultId, tokenList);
    }
}
