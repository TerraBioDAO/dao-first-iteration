// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { ProposerAdapter, Slot, Adapter } from "../abstracts/ProposerAdapter.sol";
import { IBank } from "../interfaces/IBank.sol";
import { IAgora } from "../interfaces/IAgora.sol";

/**
 * @title Adapter for interacting with Bank for funding and commitment process
 * @notice Members can create transactions request and deposit into DAO's vaults
 *
 * @dev Implementation for executing transaction request is not implemented
 */
contract Financing is ProposerAdapter {
    using Slot for bytes28;

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

    /// @dev track transaction requests by their hash
    mapping(bytes28 => TransactionRequest) private _requests;

    /// @param core address of DaoCore
    constructor(address core) Adapter(core, Slot.FINANCING) {}

    /*//////////////////////////////////////////////////////////
                            PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Create a transaction request, requests must be validated by
     * an admin
     *
     * @param voteId vote parameters id
     * @param amount amount to transfer
     * @param applicant desitination address of the transaction
     * @param vaultId vaultID from which funds are moved
     * @param tokenAddr token address
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
     * @notice Allow admins to create a new vault in the DAO
     *
     * @param vaultId vaultID from which funds are moved
     * @param tokenList tokens address list
     */
    function createVault(bytes4 vaultId, address[] memory tokenList) external onlyAdmin {
        IBank(_slotAddress(Slot.BANK)).createVault(vaultId, tokenList);
    }

    /**
     * @notice Allow users to deposit token from their account
     * @dev Users cannot deposit for another address because it open a
     * risk of a misuse of the Bank approval
     *
     * @param vaultId vaultID to deposit token
     * @param tokenAddr address of the token to deposit
     * @param amount amount of token
     */
    function vaultDeposit(
        bytes4 vaultId,
        address tokenAddr,
        uint128 amount
    ) external {
        IBank(_slotAddress(Slot.BANK)).vaultDeposit(vaultId, tokenAddr, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////
                        INTERNAL FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @dev Implementation of {_executeProposal}, function not implemented
     * yet
     *
     * @param proposalId transaction request to execute
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
