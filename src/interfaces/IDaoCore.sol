// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IDaoCore {
    event SlotEntryChanged(
        bytes4 indexed slot,
        bool indexed isExtension,
        address oldContractAddr,
        address newContractAddr
    );

    event MemberStatusChanged(
        address indexed member,
        bytes32 indexed roles,
        bool indexed actualValue
    );

    struct Entry {
        bytes4 slot;
        bool isExtension;
        address contractAddr;
    }

    function batchChangeMembersStatus(
        address[] memory accounts,
        bytes32[] memory roles,
        bool[] memory values
    ) external;

    function batchChangeSlotEntries(bytes4[] memory slots, address[] memory contractsAddr) external;

    function changeSlotEntry(bytes4 slot, address contractAddr) external;

    function changeMemberStatus(
        address account,
        bytes32 role,
        bool value
    ) external;

    function membersCount() external returns (uint256);

    function hasRole(address account, bytes32 role) external returns (bool);

    function getNumberOfRoles() external view returns (uint256);

    function rolesActive(bytes32 role) external view returns (bool);

    function getRolesByIndex(uint256 index) external view returns (bytes32);

    function isSlotActive(bytes4 slot) external view returns (bool);

    function isSlotExtension(bytes4 slot) external view returns (bool);

    function getSlotContractAddr(bytes4 slot) external view returns (address);

    function legacyManaging() external view returns (address);
}
