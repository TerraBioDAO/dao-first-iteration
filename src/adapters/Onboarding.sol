// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../helpers/Slot.sol";
import "../core/IDaoCore.sol";
import "../guards/SlotGuard.sol";

contract Onboarding is SlotGuard {
    constructor(address core) SlotGuard(core, Slot.ONBOARDING) {}

    function joinDao() external {
        require(
            !IDaoCore(_core).hasRole(msg.sender, Slot.USER_EXISTS),
            "Onboarding: already a member"
        );
        IDaoCore(_core).changeMemberStatus(
            msg.sender, Slot.USER_EXISTS, true
        );
    }

    function quitDao() external {
        require(
            IDaoCore(_core).hasRole(msg.sender, Slot.USER_EXISTS),
            "Onboarding: not a member"
        );
        IDaoCore(_core).changeMemberStatus(
            msg.sender, Slot.USER_EXISTS, false
        );
    }

    function setAdminMember(address account, bool isAdmin)
        external
        onlyAdmin
    {
        require(
            IDaoCore(_core).hasRole(account, Slot.USER_ADMIN)
                != isAdmin,
            "Onboarding: no role changed"
        );
        IDaoCore(_core).changeMemberStatus(
            account, Slot.USER_ADMIN, isAdmin
        );
    }
}
