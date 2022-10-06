// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "../guards/SlotGuard.sol";
import "../extensions/Bank.sol";
import "../adapters/Voting.sol";

contract Financing is SlotGuard {
    struct Proposal {
        address applicant; // the proposal applicant address, can not be a reserved address
        uint256 amount; // the amount requested for funding
        address token; // the token address in which the funding must be sent to
    }

    mapping(bytes28 => Proposal) public proposals;

    constructor(address core) SlotGuard(core, Slot.FINANCING) {}

    /**
     * @notice Creates and sponsors a financing proposal.
     * @dev Applicant address must not be reserved ?
     * @dev Token address must be allowed/supported by the DAO Bank.
     * @dev Requested amount must be greater than zero.
     * @dev Only members of the DAO can sponsor a financing proposal.
     * @param proposal The Proposal data
     */
    function submitProposal(Proposal memory proposal)
        external
        onlyMember
    {
        require(proposal.amount > 0, "invalid requested amount");
        IDaoCore dao = IDaoCore(_core);
        Bank bank = Bank(dao.getSlotContractAddress(Slot.BANK));
        require(bank.isTokenAllowed(proposal.token), "token not allowed");
        require(
            DaoHelper.isNotReservedAddress(proposal.applicant),
            "applicant using reserved address"
        );

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
     * @dev Only proposals that were sponsored are accepted.
     * @dev Only proposals that passed can get processed and have the funds released.
     * @param dao The DAO Address.
     * @param proposalId The proposal id.
     */
    // slither-disable-next-line reentrancy-benign
    function processProposal(bytes32 proposalId) external onlyCore {
        Proposal memory proposal = proposals[bytes28(proposalId << 32)];

        Voting voting = Voting(dao.getSlotContractAddress(Slot.VOTING));
        require(address(voting) != address(0), "adapter not found");

        require(
            voting.voteResult(dao, proposalId) == Voting.VotingState.PASS,
            "proposal needs to pass"
        );
        dao.processProposal(proposalId);
        Bank bank = Bank(dao.getSlotContractAddress(Slot.BANK));

        bank.subtractFromBalance(details.token, details.amount);
        bank.addToBalance(details.applicant, details.token, details.amount);

        delete proposals[bytes28(proposalId << 32)];
    }
}
