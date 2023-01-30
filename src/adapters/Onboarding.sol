// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Adapter } from "../abstracts/Adapter.sol";
import { Slot } from "../helpers/Slot.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";

/**
 * @notice simpliest implementation of the Onboarding process
 */
contract Onboarding is Adapter {
    constructor(address core) Adapter(core, Slot.ONBOARDING) {}

    /**
     * @notice any address can become a member in the DAO
     */
    function joinDao() external {
        IDaoCore(_core).changeMemberStatus(msg.sender, ROLE_MEMBER, true);
    }

    /**
     * @notice any address can quit the DAO
     * tokens deposited in the DAO are not refunded
     */
    function quitDao() external {
        IDaoCore(_core).changeMemberStatus(msg.sender, ROLE_MEMBER, false);
    }

    /**
     * @notice any admin can add or remove an admin in the DAO
     * An admin can self-remove the role, and thus block the DAO
     */
    function setAdminMember(address account, bool setAsAdmin) external onlyAdmin {
        if (!IDaoCore(_core).hasRole(account, ROLE_MEMBER) && setAsAdmin) {
            (
                address[] memory accounts,
                bytes32[] memory roles,
                bool[] memory values
            ) = _getBatchParameter(2);
            accounts[0] = account;
            accounts[1] = account;
            roles[0] = ROLE_MEMBER;
            roles[1] = ROLE_ADMIN;
            values[0] = true;
            values[1] = true;
            IDaoCore(_core).batchChangeMembersStatus(accounts, roles, values);
            return;
        }

        IDaoCore(_core).changeMemberStatus(account, ROLE_ADMIN, setAsAdmin);
    }

    function _getBatchParameter(uint256 length)
        private
        pure
        returns (
            address[] memory accounts,
            bytes32[] memory roles,
            bool[] memory values
        )
    {
        accounts = new address[](length);
        roles = new bytes32[](length);
        values = new bool[](length);
    }
}
