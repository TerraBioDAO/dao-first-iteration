// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/Adapter.sol";

contract Onboarding is Adapter {
    constructor(address core) Adapter(core, Slot.ONBOARDING) {}

    function joinDao() external {
        IDaoCore(_core).changeMemberStatus(msg.sender, Slot.USER_EXISTS, true);
    }

    function quitDao() external {
        IDaoCore(_core).changeMemberStatus(msg.sender, Slot.USER_EXISTS, false);
    }

    function setAdminMember(address account, bool isAdmin) external onlyAdmin {
        if (isAdmin) {
            IDaoCore(_core).addNewAdmin(account);
        } else {
            IDaoCore(_core).changeMemberStatus(account, Slot.USER_ADMIN, false);
        }
    }
}
