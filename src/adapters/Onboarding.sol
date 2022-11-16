// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/Adapter.sol";

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
    function setAdminMember(address account, bool isAdmin) external onlyAdmin {
        if (isAdmin) {
            IDaoCore(_core).addNewAdmin(account);
        } else {
            IDaoCore(_core).changeMemberStatus(account, ROLE_ADMIN, false);
        }
    }
}
