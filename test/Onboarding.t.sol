// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "src/core/DaoCore.sol";
import "src/adapters/Onboarding.sol";
import "test/base/BaseDaoTest.sol";

contract Onboarding_test is BaseDaoTest {
    Onboarding public onboarding;

    address public constant OWNER = address(0xAD);
    address public constant USER = address(502);
    address public ONBOARDING;
    address public ENTRY = address(503);

    function setUp() public {
        dao = new DaoCore(OWNER);
        onboarding = new Onboarding(address(dao));

        vm.prank(OWNER);
        dao.changeSlotEntry(Slot.ONBOARDING, address(onboarding));
    }

    function testJoinDao(address user) public {
        vm.assume(user != address(0) && user != OWNER);
        vm.prank(user);
        onboarding.joinDao();

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, ROLE_MEMBER));
    }

    function testQuitDao(address user) public {
        vm.assume(user != address(0) && user != OWNER);
        vm.startPrank(user);
        onboarding.joinDao();

        onboarding.quitDao();

        assertEq(dao.membersCount(), 1);
        assertFalse(dao.hasRole(user, ROLE_MEMBER));
    }

    function testAddNewAdminMember(address user) public {
        vm.assume(user != address(0) && user != OWNER);
        vm.prank(OWNER);
        onboarding.setAdminMember(user, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, ROLE_MEMBER));
        assertTrue(dao.hasRole(user, ROLE_ADMIN));
    }

    function testSetAdminMember(address user) public {
        vm.assume(user != address(0) && user != OWNER);
        vm.prank(user);
        onboarding.joinDao();

        vm.prank(OWNER);
        onboarding.setAdminMember(user, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, ROLE_MEMBER));
        assertTrue(dao.hasRole(user, ROLE_ADMIN));
    }

    function testCannotSetAdminMember(address user) public {
        vm.assume(user != address(0) && user != OWNER);
        vm.expectRevert("Adapter: not an admin");
        onboarding.setAdminMember(user, true);
    }

    function testRemoveAdminMember(address user) public {
        vm.assume(user != address(0) && user != OWNER);
        vm.prank(OWNER);
        onboarding.setAdminMember(user, true);

        vm.prank(user);
        onboarding.setAdminMember(OWNER, false);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(OWNER, ROLE_MEMBER));
        assertFalse(dao.hasRole(OWNER, ROLE_ADMIN));
    }
}
