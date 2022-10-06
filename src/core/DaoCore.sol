// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "./IDaoCore.sol";
import "../guards/CoreGuard.sol";

/**
 * @notice Main contract, keep states of the DAO
 */

contract DaoCore is IDaoCore, CoreGuard {
    /// @notice The map to track all members of the DAO with their roles or credits
    mapping(address => mapping(bytes4 => bool)) public members;
    uint256 public membersCount;

    /// @notice keeps track of Extensions and Adapters
    mapping(bytes4 => Entry) public entries;

    /// @notice The map that keeps track of all proposasls submitted to the DAO
    mapping(bytes32 => Proposal) public proposals;

    constructor(address admin, address managingContractAddr)
        CoreGuard(address(this), Slot.CORE)
    {
        _changeMemberStatus(admin, Slot.USER_EXISTS, true);
        _changeMemberStatus(admin, Slot.USER_ADMIN, true);
        address managingAddr = managingContractAddr == address(0)
            ? admin
            : managingContractAddr;
        _changeSlotEntry(Slot.MANAGING, managingAddr, false);
    }

    function changeSlotEntry(
        bytes4 slot,
        address contractAddr,
        bool isExtension
    ) external onlyAdapter(Slot.MANAGING) {
        _changeSlotEntry(slot, contractAddr, isExtension);
    }

    function changeMemberStatus(address account, bytes4 role, bool value)
        external
        onlyAdapter(Slot.ONBOARDING)
    {
        _changeMemberStatus(account, role, value);
    }

    function submitProposal(
        bytes32 proposalId,
        address initiater,
        address votingContract
    ) external onlyAdapter(bytes4(proposalId)) {
        require(
            initiater != address(0) && votingContract != address(0),
            "Core: zero address used"
        );

        bytes4 slot = bytes4(proposalId);

        proposals[proposalId] = Proposal(
            slot,
            bytes28(proposalId << 32),
            initiater,
            votingContract,
            ProposalStatus.EXISTS
        );
        emit ProposalSubmitted(slot, initiater, votingContract, proposalId);
    }

    function processProposal(bytes32 proposalId) external {
        bool isVoteEnded = _hasVotingConsensus(proposalId);

        address adapterAddr = entries[bytes4(proposalId)].contractAddr;
        // IAdapters(adapterAddr).processProposal(proposalId); no processing so far
    }

    function hasRole(address account, bytes4 role)
        external
        view
        returns (bool)
    {
        return members[account][role];
    }

    function slotActive(bytes4 slot) external view returns (bool) {
        return entries[slot].slot != Slot.EMPTY;
    }

    function isSlotExtension(bytes4 slot) external view returns (bool) {
        return entries[slot].isExtension;
    }

    function getSlotContractAddress(bytes4 slot)
        external
        view
        returns (address)
    {
        return entries[slot].contractAddr;
    }

    function _changeMemberStatus(address account, bytes4 role, bool value)
        internal
    {
        require(account != address(0), "Core: zero address used");
        require(members[account][role] != value, "Core: role not changing");

        if (role == Slot.USER_EXISTS) {
            unchecked {
                value ? ++membersCount : --membersCount;
            }
        }

        members[account][role] = value;
        emit MemberStatusChanged(account, role, value);
    }

    function _changeSlotEntry(
        bytes4 slot,
        address newContractAddr,
        bool isExtension
    ) internal {
        require(slot != Slot.EMPTY, "Core: empty slot");
        Entry memory e = entries[slot];

        if (newContractAddr != address(0)) {
            // add entry
            require(
                e.isExtension == isExtension, "Core: wrong entry setup"
            );
            e.slot = slot;
            e.contractAddr = newContractAddr;
            e.isExtension = isExtension;
        } else {
            // remove entry
            delete entries[slot];
        }

        emit SlotEntryChanged(
            slot, isExtension, e.contractAddr, newContractAddr
            );
    }

    function _hasVotingConsensus(bytes32 proposalId)
        internal
        view
        returns (bool)
    {
        Proposal memory p = proposals[proposalId];
        require(
            p.votingContract == msg.sender, "Core: only voting contract"
        );

        // check vote result
    }
}
