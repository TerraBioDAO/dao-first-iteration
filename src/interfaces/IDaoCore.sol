// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IDaoCore {
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

    function batchChangeEntriesStatus(
        address[] memory entriesAddr,
        bytes32[] memory roles,
        bool[] memory values
    ) external;

    function createSubRole(bytes32 subRole, bytes32 role) external;

    function removeSubRole(bytes32 subRole, bytes32 role) external;

    function numberOfMembers() external view returns (uint256);

    function membersList() external view returns (address[] memory);

    function numberOfEntries() external view returns (uint256);

    function entriesList() external view returns (address[] memory);

    function numberOfRoles() external view returns (uint256);

    function rolesList() external view returns (bytes32[] memory);

    function roleExist(bytes32 role) external view returns (bool);

    // ---
    function getSlotContractAddr(bytes4 slot) external view returns (address);

    function legacyManaging() external view returns (address);

    function isSlotActive(bytes4 slot) external view returns (bool);

    function isSlotExtension(bytes4 slot) external view returns (bool);
}
