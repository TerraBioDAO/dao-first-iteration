// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/ProposerAdapter.sol";
import "../interfaces/IBank.sol";
import "../interfaces/IAgora.sol";

/**
 * @notice contract which interact with the Bank to manage funds in the DAO
 */
contract Financing is ProposerAdapter {
    using Slot for bytes28;

    address public applicant; // the proposal applicant address
    uint256 public amount; // the amount requested for funding
    bytes4 public vaultId; // the vault to fund
    address public tokenAddr; // the address of the token related to amount

    struct TransactionRequest {
        address applicant; // the proposal applicant address
        uint256 amount; // the amount requested for funding
        bytes4 vaultId; // the vault to fund
        address tokenAddr; // the address of the token related to amount
    }

    mapping(bytes28 => TransactionRequest) private _requests;

    constructor(address core) Adapter(core, Slot.FINANCING) {}

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
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
    function submitTransactionRequest(
        bytes4 voteId,
        uint256 amount,
        address applicant,
        bytes4 vaultId,
        address tokenAddr,
        uint32 minStartTime
    ) external onlyMember {
        require(amount > 0, "Financing: insufficiant amount");
        TransactionRequest memory proposal = TransactionRequest(
            applicant,
            amount,
            vaultId,
            tokenAddr
        );

        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        _requests[proposalId] = proposal;

        IBank(_slotAddress(Slot.BANK)).vaultCommit(vaultId, tokenAddr, uint128(amount));
        IAgora(_slotAddress(Slot.AGORA)).submitProposal(
            Slot.FINANCING,
            proposalId,
            false, // admin validation needed
            voteId,
            minStartTime,
            msg.sender
        );

        _newProposal();
    }

    /**
     * @notice finalize proposal
     * @dev Only admin can create a Vault.
     * @param proposalId proposal id (bytes32)
     * requirements :
     * - Only Member can finalize a proposal.
     * - Proposal status must be TO_FINALIZE
     */
    function finalizeProposal(bytes32 proposalId) external override onlyMember {
        (IAgora.VoteResult result, IAgora agora) = _checkProposalResult(proposalId);

        if (result == IAgora.VoteResult.ACCEPTED) {
            _executeProposal(proposalId);
        }

        delete _requests[bytes28(proposalId << 32)];
        agora.finalizeProposal(proposalId, msg.sender, result);
    }

    /**
     * @notice Create a vault
     * @dev Only admin can create a Vault.
     * @param vaultId vault id
     * @param tokenList array of token addresses
     * requirements :
     * - Only Admin can create a vault.
     *
     * SECURITY: Agora do not check if this is an ERC20, a check can be done there,
     * reminder that checking an ERC20 do not prevent an attacker contract to mock it.
     */
    function createVault(bytes4 vaultId, address[] memory tokenList) external onlyAdmin {
        IBank(_slotAddress(Slot.BANK)).createVault(vaultId, tokenList);
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    /**
     * @notice Execute a financing proposal.
     * @param proposalId The proposal id.
     */
    function _executeProposal(bytes32 proposalId) internal override {
        super._executeProposal(proposalId);

        TransactionRequest memory proposal_ = _requests[bytes28(proposalId << 32)];

        IBank(_slotAddress(Slot.BANK)).vaultTransfer(
            proposal_.vaultId,
            proposal_.tokenAddr,
            proposal_.applicant,
            uint128(proposal_.amount)
        );
    }
}
