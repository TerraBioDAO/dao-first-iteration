// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

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

    struct Entry {
        bytes4 slot;
        bool isExtension;
        address contractAddr;
    }

    function changeSlotEntry(bytes4 slot, address contractAddr) external;

    function addNewAdmin(address account) external;

    function changeMemberStatus(
        address account,
        bytes4 role,
        bool value
    ) external;

    function membersCount() external returns (uint256);

    function hasRole(address account, bytes4 role) external returns (bool);

    function getRolesList() external returns (bytes4[] memory);

    function isSlotActive(bytes4 slot) external view returns (bool);

    function isSlotExtension(bytes4 slot) external view returns (bool);

    function getSlotContractAddr(bytes4 slot) external view returns (address);

    function legacyManaging() external view returns (address);
}
