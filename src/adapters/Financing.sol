// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { ProposerAdapter, Slot, Adapter } from "../abstracts/ProposerAdapter.sol";
import { IBank } from "../interfaces/IBank.sol";
import { IAgora } from "../interfaces/IAgora.sol";

/**
 * @notice contract which interact with the Bank to manage funds in the DAO
 */
contract Financing is ProposerAdapter {
    using Slot for bytes28;

    // MAY BE: Create an `event` as a receipt?

    /**
     * @notice Financing proposals are request for transaction
     * from an existing vault on {Bank} to an address
     */
    struct TransactionRequest {
        address applicant; // the proposal applicant address
        uint256 amount; // the amount requested for funding => uint128? (no space gained)
        bytes4 vaultId; // the vault to fund
        address tokenAddr; // the address of the token related to amount
    }

    mapping(bytes28 => TransactionRequest) private _requests;

    constructor(address core) Adapter(core, Slot.FINANCING) {}

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
    /**
     * @notice Creates financing proposal, proposal must be validated by
     * an admin
     * @param voteId vote parameters id
     * @param amount of the proposal
     * @param applicant of the proposal
     * @param vaultId vault id
     * @param tokenAddr token address
     * requirements :
     * - Only MEMBER role can create a financing proposal.
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

        _newProposal();

        _requests[proposalId] = proposal;
        IBank(_slotAddress(Slot.BANK)).vaultCommit(vaultId, tokenAddr, applicant, uint128(amount));
        IAgora(_slotAddress(Slot.AGORA)).submitProposal(
            Slot.FINANCING,
            proposalId,
            false, // admin validation needed
            voteId,
            minStartTime,
            msg.sender
        );
    }

    /**
     * @notice Create a vault
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

    /**
     * @notice allow anyone to deposit in a specific vault in the DAO
     * @dev users cannot deposit for another address because it open a
     * risk of a misuse of the Bank approval
     */
    function vaultDeposit(
        bytes4 vaultId,
        address tokenAddr,
        uint128 amount
    ) external {
        IBank(_slotAddress(Slot.BANK)).vaultDeposit(vaultId, tokenAddr, msg.sender, amount);
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    /**
     * @notice Execute a financing proposal.
     * @param proposalId The proposal id.
     */
    function _executeProposal(bytes32 proposalId) internal override {
        TransactionRequest memory proposal_ = _requests[_readProposalId(proposalId)];

        IBank(_slotAddress(Slot.BANK)).vaultTransfer(
            proposal_.vaultId,
            proposal_.tokenAddr,
            proposal_.applicant,
            uint128(proposal_.amount)
        );
    }
}
