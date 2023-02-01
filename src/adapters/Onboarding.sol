// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Adapter } from "../abstracts/Adapter.sol";
import { Slot } from "../helpers/Slot.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";

/**
 * @title Contract in charge of register or remove member into the DAO
 * @notice Users can join and quit the DAO whenever they want
 *
 * @dev It is the simplier implementation of an onboarding feature, designed
 * for testing purpose.
 */
contract Onboarding is Adapter {
    /// @param core address of DaoCore
    constructor(address core) Adapter(core, Slot.ONBOARDING) {}

    /**
     * @notice Allow users (or any contract) to become a member of the DAO
     */
    function joinDao() external {
        IDaoCore(_core).changeMemberStatus(msg.sender, ROLE_MEMBER, true);
    }

    /**
     * @notice Allow members to quit the DAO, users should withdraw funds
     * from the DAO before quiting the DAO.
     */
    function quitDao() external {
        IDaoCore(_core).changeMemberStatus(msg.sender, ROLE_MEMBER, false);
    }

    /**
     * @notice Allow admins to register or revoke admins from the DAO
     * @dev Admin are able to self-revoke the admin role, pay attention
     * to not leave the DAO without admin before necessary implementation are done
     *
     * @param account address to grant or revoke the admin role
     * @param setAsAdmin boolean to grant or revoke the admin
     */
    function setAdminMember(address account, bool setAsAdmin) external onlyAdmin {
        if (!IDaoCore(_core).hasRole(account, ROLE_MEMBER) && setAsAdmin) {
            address[] memory accounts = new address[](2);
            bytes32[] memory roles = new bytes32[](2);
            bool[] memory values = new bool[](2);
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
}
