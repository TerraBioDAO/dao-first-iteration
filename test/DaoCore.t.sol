// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";
import "test/base/BaseDaoTest.sol";

contract DaoCore_test is BaseDaoTest {
    address public MANAGING;
    address public ONBOARDING;
    address public constant USER = address(502);

    function setUp() public {
        vm.label(ADMIN, "Admin");
        vm.label(MANAGING, "Managing");
        vm.label(ONBOARDING, "Onboarding");

        _deployDao(address(501));
        MANAGING = _branchMock(Slot.MANAGING, false);
    }

    // changeSlotEntry()
    function testAddSlotEntry(bytes4 slot, address addr) public {
        vm.assume(slot != Slot.EMPTY && addr != address(0));
        addr = _newEntry(slot, false);
        vm.prank(MANAGING);
        dao.changeSlotEntry(slot, addr);

        assertTrue(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), addr);
        assertFalse(dao.isSlotExtension(slot));
    }

    function testCannotAddSlotEntry() public {
        ONBOARDING = address(600);
        vm.expectRevert("CoreGuard: not the right adapter");
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);

        vm.startPrank(MANAGING);
        vm.expectRevert("Core: empty slot");
        dao.changeSlotEntry(Slot.EMPTY, ONBOARDING);

        vm.expectRevert("Core: inexistant slotId() impl");
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);

        ONBOARDING = _newEntry(Slot.FINANCING, false);
        vm.expectRevert("Core: slot & address not match");
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);
    }

    function testRemoveSlotEntry(bytes4 slot, address addr) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.MANAGING && addr != address(0));

        addr = _newEntry(slot, false);
        vm.startPrank(MANAGING);
        dao.changeSlotEntry(slot, addr);
        dao.changeSlotEntry(slot, address(0));

        assertFalse(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), address(0));
        assertFalse(dao.isSlotExtension(slot));
    }

    function testReplaceSlotEntry(bytes4 slot, address addr) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.MANAGING && addr != address(0));
        address fixedAddr = _newEntry(slot, false);
        addr = _newEntry(slot, false);

        vm.startPrank(MANAGING);
        dao.changeSlotEntry(slot, fixedAddr);
        dao.changeSlotEntry(slot, addr);

        assertTrue(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), addr);
        assertFalse(dao.isSlotExtension(slot));
    }

    function testCannotReplaceSlotEntry(bytes4 slot, address addr) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.MANAGING && addr != address(0));
        address fixedAddr = _newEntry(slot, false);
        addr = _newEntry(slot, true);

        vm.startPrank(MANAGING);
        dao.changeSlotEntry(slot, fixedAddr);

        vm.expectRevert("Core: wrong entry setup");
        dao.changeSlotEntry(slot, addr);
    }

    event SlotEntryChanged(
        bytes4 indexed slot,
        bool indexed isExtension,
        address oldContractAddr,
        address newContractAddr
    );

    function testEmitOnChangeSlotEntry(bytes4 slot, address addr) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.MANAGING && addr != address(0));
        addr = _newEntry(slot, false);

        vm.prank(MANAGING);
        vm.expectEmit(true, true, false, true, address(dao));
        emit SlotEntryChanged(slot, false, address(0), addr);
        dao.changeSlotEntry(slot, addr);
    }

    // changeMemberStatus()
    function _branchOnboarding() internal {
        ONBOARDING = _newEntry(Slot.ONBOARDING, false);
        vm.prank(MANAGING);
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);
    }

    function testChangeMemberStatus(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        _branchOnboarding();
        vm.prank(ONBOARDING);
        dao.changeMemberStatus(user, Slot.USER_EXISTS, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, Slot.USER_EXISTS));
    }

    function testCannotChangeMemberStatus() public {
        vm.expectRevert("CoreGuard: not the right adapter");
        dao.changeMemberStatus(USER, Slot.USER_EXISTS, true);

        _branchOnboarding();
        vm.startPrank(ONBOARDING);
        dao.changeMemberStatus(USER, Slot.USER_EXISTS, true);

        vm.expectRevert("Core: role not changing");
        dao.changeMemberStatus(USER, Slot.USER_EXISTS, true);

        vm.expectRevert("Core: zero address used");
        dao.changeMemberStatus(address(0), Slot.USER_EXISTS, true);
    }

    function testAddNewAdmin() public {
        _branchOnboarding();
        vm.prank(ONBOARDING);
        dao.addNewAdmin(USER);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(USER, Slot.USER_EXISTS));
        assertTrue(dao.hasRole(USER, Slot.USER_ADMIN));
    }

    function testCannotAddNewAdmin() public {
        vm.expectRevert("CoreGuard: not the right adapter");
        dao.addNewAdmin(USER);

        _branchOnboarding();
        vm.startPrank(ONBOARDING);
        vm.expectRevert("Core: zero address used");
        dao.addNewAdmin(address(0));

        dao.addNewAdmin(USER);
        vm.expectRevert("Core: already an admin");
        dao.addNewAdmin(USER);
    }

    function testRevokeMember(address user) public {
        vm.assume(user != address(0) && user != ADMIN);
        _branchOnboarding();

        vm.startPrank(ONBOARDING);
        dao.changeMemberStatus(user, Slot.USER_EXISTS, true);
        dao.changeMemberStatus(user, Slot.USER_PROPOSER, true);

        dao.changeMemberStatus(user, Slot.USER_EXISTS, false);

        assertEq(dao.membersCount(), 1);
        assertFalse(dao.hasRole(user, Slot.USER_EXISTS));
        assertFalse(dao.hasRole(user, Slot.USER_PROPOSER));
    }

    function testGetRoles() public {
        bytes4[] memory roles = dao.getRolesList();

        assertEq(roles[0], Slot.USER_EXISTS);
        assertEq(roles[1], Slot.USER_ADMIN);
        assertEq(roles[2], Slot.USER_PROPOSER);
    }
}
