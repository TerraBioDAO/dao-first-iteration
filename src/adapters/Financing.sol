// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/ProposerAdapter.sol";
import "../interfaces/IBank.sol";
import "../interfaces/IAgora.sol";

/**
 * @notice Financing submit and process proposals to finance projects.
 * Financing is only in TBIO
 */
contract Financing is ProposerAdapter {
    using Slot for bytes28;

    struct Proposal {
        address applicant; // the proposal applicant address
        uint256 amount; // the amount requested for funding
        bytes4 vaultId; // the vault to fund
        address tokenAddr; // the address of the token related to amount
    }

    mapping(bytes28 => Proposal) private proposals;

    constructor(address core) Adapter(core, Slot.FINANCING) {}

    /**
     * @notice Creates financing proposal. Only PROPOSER role can create a financing proposal.
     * @param voteId vote parameters id
     * @param amount of the proposal
     * @param applicant of the proposal
     * @param vaultId vault id
     * @param tokenAddr token address
     * requirements :
     * - Only PROPOSER role can create a financing proposal.
     * - Requested amount must be greater than zero.
     */
    function submitProposal(
        bytes4 voteId,
        uint256 amount,
        address applicant,
        bytes4 vaultId,
        address tokenAddr
    ) external onlyProposer {
        require(amount > 0, "Financing: invalid requested amount");
        Proposal memory proposal = Proposal(applicant, amount, vaultId, tokenAddr);

        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        proposals[proposalId] = proposal;
        super._newProposal();

        _getBank().vaultCommit(vaultId, tokenAddr, uint128(amount));

        // startime = 0 => startime = timestamp
        // admin validation depends on sender role
        _getAgora().submitProposal(Slot.FINANCING, proposalId, true, voteId, 0, msg.sender);
    }

    /**
     * @notice Create a vault
     * @dev Only admin can create a Vault.
     * @param vaultId vault id
     * @param tokenList array of token addresses
     * requirements :
     * - Only Admin can create a vault.
     */
    function createVault(bytes4 vaultId, address[] memory tokenList) external onlyAdmin {
        _getBank().createVault(vaultId, tokenList);
    }

    /**
     * @notice finalize proposal
     * @dev Only admin can create a Vault.
     * @param coreProposalId proposal id (bytes32)
     * requirements :
     * - Only Member can finalize a proposal.
     * - Proposal status must be TO_FINALIZE
     */
    function finalizeProposal(bytes32 coreProposalId) external override onlyMember {
        IAgora agora = _getAgora();

        require(
            agora.getProposalStatus(coreProposalId) == IAgora.ProposalStatus.TO_FINALIZE,
            "Financing: proposal cannot be finalized"
        );

        IAgora.VoteResult voteResult = agora.getVoteResult(coreProposalId);

        delete proposals[bytes28(coreProposalId << 32)];

        if (voteResult == IAgora.VoteResult.ACCEPTED) {
            _executeProposal(coreProposalId);
        }

        agora.finalizeProposal(coreProposalId, msg.sender, voteResult);
    }

    /**
     * @notice Execute a financing proposal.
     * @param coreProposalId The proposal id.
     */
    function _executeProposal(bytes32 coreProposalId) internal override {
        super._executeProposal(coreProposalId);

        Proposal memory proposal = proposals[bytes28(coreProposalId << 32)];

        _getBank().vaultTransfer(
            proposal.vaultId,
            proposal.tokenAddr,
            proposal.applicant,
            uint128(proposal.amount)
        );
    }

    function _getBank() internal view returns (IBank) {
        return IBank(IDaoCore(_core).getSlotContractAddr(Slot.BANK));
    }

    function _getAgora() internal view returns (IAgora) {
        return IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
    }
}
