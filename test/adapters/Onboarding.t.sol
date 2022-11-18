// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "test/base/BaseDaoTest.sol";
import "src/core/DaoCore.sol";
import "src/adapters/Onboarding.sol";

contract Onboarding_test is BaseDaoTest {
    Onboarding public onboarding;

    address public ONBOARDING;
    address public ENTRY = address(503);

    function setUp() public {
        _deployDao(address(501));
        onboarding = new Onboarding(DAO);
        ONBOARDING = address(onboarding);
        _branch(Slot.ONBOARDING, ONBOARDING);
    }

    function testJoinDao(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.prank(user);
        onboarding.joinDao();

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, ROLE_MEMBER));
    }

    function testQuitDao(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.startPrank(user);
        onboarding.joinDao();

        onboarding.quitDao();

        assertEq(dao.membersCount(), 1);
        assertFalse(dao.hasRole(user, ROLE_MEMBER));
    }

    function testAddNewAdminMember(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.prank(ADMIN);
        onboarding.setAdminMember(user, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, ROLE_MEMBER));
        assertTrue(dao.hasRole(user, ROLE_ADMIN));
    }

    function testSetAdminMember(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        vm.prank(user);
        onboarding.joinDao();

        vm.prank(ADMIN);
        onboarding.setAdminMember(user, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, ROLE_MEMBER));
        assertTrue(dao.hasRole(user, ROLE_ADMIN));
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
        assertTrue(dao.hasRole(ADMIN, ROLE_MEMBER));
        assertFalse(dao.hasRole(ADMIN, ROLE_ADMIN));
    }
}
