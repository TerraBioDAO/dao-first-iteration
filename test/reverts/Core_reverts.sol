// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "src/interfaces/IDaoCore.sol";

contract Core_reverts is IDaoCore {
    function changeSlotEntry(bytes4 slot, address contractAddr) external pure {
        slot == slot;
        contractAddr == contractAddr;

        revert();
    }

    function addNewAdmin(address account) external pure {
        account == account;

        revert();
    }

    function changeMemberStatus(
        address account,
        bytes4 role,
        bool value
    ) external pure {
        account == account;
        role == role;
        value == value;

        revert();
    }

    function membersCount() external pure returns (uint256) {
        revert();
    }

    function hasRole(address account, bytes4 role) external pure returns (bool) {
        account == account;
        role == role;

        revert();
    }

    function getRolesList() external pure returns (bytes4[] memory) {
        revert();
    }

    function isSlotActive(bytes4 slot) external pure returns (bool) {
        slot == slot;

        revert();
    }

    function isSlotExtension(bytes4 slot) external pure returns (bool) {
        slot == slot;

        revert();
    }

    function getSlotContractAddr(bytes4 slot) external pure returns (address) {
        slot == slot;

        revert();
    }
}
