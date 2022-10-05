// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IDaoCore {
    event SlotEntryChanged(
        bytes4 indexed slot,
        bool indexed isExtension,
        address oldContractAddr,
        address newContractAddr
    );

    event MemberStatusChanged(
        address indexed member,
        bytes4 indexed roles,
        bool indexed actualValue
    );

    event ProposalSubmitted(
        bytes4 indexed slot,
        address indexed initiater,
        address indexed votingContract,
        bytes32 proposalId
    );

    enum ProposalStatus {
        EXISTS,
        SUSPENDED,
        ACCEPTED,
        REJECTED
    }

    struct Entry {
        bytes4 slot;
        bool isExtension;
        address contractAddr;
    }

    struct Proposal {
        bytes4 slot;
        bytes28 proposalId;
        address fromMember;
        address votingContract;
        ProposalStatus status;
    }

    function changeSlotEntry(
        bytes4 slot,
        address contractAddr,
        bool isExtension
    ) external;

    function changeMemberStatus(
        address account,
        bytes4 role,
        bool value
    ) external;

    function submitProposal(
        bytes32 proposalId,
        address initiater,
        address votingContract
    ) external;

    function processProposal(bytes32 proposalId) external;

    function hasRole(address account, bytes4 role) external returns (bool);

    function slotActive(bytes4 slot) external view returns (bool);

    function isSlotExtension(bytes4 slot) external view returns (bool);

    function slotContract(bytes4 slot) external view returns (address);
}
