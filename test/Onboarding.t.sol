// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";
import "src/adapters/Onboarding.sol";

contract FakeEntry {
    bytes4 public slotId;
    bool public isExtension;

    constructor(bytes4 slot, bool isExt) {
        slotId = slot;
        isExtension = isExt;
    }
}

contract Onboarding_test is Test {
    DaoCore public dao;
    Onboarding public onboarding;

    address public constant ADMIN = address(0xAD);
    address public constant USER = address(502);
    address public ONBOARDING;
    address public ENTRY = address(503);

    function _newEntry(bytes4 slot, bool isExt) internal returns (address entry) {
        entry = address(new FakeEntry(slot, isExt));
    }

    function setUp() public {
        dao = new DaoCore(ADMIN);
        onboarding = new Onboarding(address(dao));

        vm.prank(ADMIN);
        dao.changeSlotEntry(Slot.ONBOARDING, address(onboarding));
    }

    function testJoinDao(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.prank(user);
        onboarding.joinDao();

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, Slot.USER_EXISTS));
    }

    function testQuitDao(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.startPrank(user);
        onboarding.joinDao();

        onboarding.quitDao();

        assertEq(dao.membersCount(), 1);
        assertFalse(dao.hasRole(user, Slot.USER_EXISTS));
    }

    function testAddNewAdminMember(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.prank(ADMIN);
        onboarding.setAdminMember(user, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, Slot.USER_EXISTS));
        assertTrue(dao.hasRole(user, Slot.USER_ADMIN));
    }

    function testSetAdminMember(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.prank(user);
        onboarding.joinDao();

        vm.prank(ADMIN);
        onboarding.setAdminMember(user, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, Slot.USER_EXISTS));
        assertTrue(dao.hasRole(user, Slot.USER_ADMIN));
    }

    function testCannotSetAdminMember(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.expectRevert("Adapter: not an admin");
        onboarding.setAdminMember(user, true);
    }

    function testRemoveAdminMember(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.prank(ADMIN);
        onboarding.setAdminMember(user, true);

        vm.prank(user);
        onboarding.setAdminMember(ADMIN, false);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(ADMIN, Slot.USER_EXISTS));
        assertFalse(dao.hasRole(ADMIN, Slot.USER_ADMIN));
    }
}
