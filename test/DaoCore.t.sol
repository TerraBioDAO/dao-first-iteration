// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

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
        vm.expectRevert("Cores: not the right adapter");
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
        vm.assume(
            slot != Slot.EMPTY &&
                slot != Slot.MANAGING &&
                slot != Slot.ONBOARDING &&
                addr != address(0)
        );
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
        dao.changeMemberStatus(user, ROLE_MEMBER, true);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(user, ROLE_MEMBER));
    }

    function testCannotChangeMemberStatus() public {
        vm.expectRevert("Cores: not the right adapter");
        dao.changeMemberStatus(USER, ROLE_MEMBER, true);

        _branchOnboarding();
        vm.startPrank(ONBOARDING);
        dao.changeMemberStatus(USER, ROLE_MEMBER, true);

        vm.expectRevert("Core: role not changing");
        dao.changeMemberStatus(USER, ROLE_MEMBER, true);

        vm.expectRevert("Core: zero address used");
        dao.changeMemberStatus(address(0), ROLE_MEMBER, true);
    }

    function testAddNewAdmin() public {
        _branchOnboarding();
        vm.prank(ONBOARDING);
        dao.addNewAdmin(USER);

        assertEq(dao.membersCount(), 2);
        assertTrue(dao.hasRole(USER, ROLE_MEMBER));
        assertTrue(dao.hasRole(USER, ROLE_ADMIN));
    }

    function testCannotAddNewAdmin() public {
        vm.expectRevert("Cores: not the right adapter");
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
        dao.changeMemberStatus(user, ROLE_MEMBER, true);
        dao.changeMemberStatus(user, ROLE_PROPOSER, true);

        dao.changeMemberStatus(user, ROLE_MEMBER, false);

        assertEq(dao.membersCount(), 1);
        assertFalse(dao.hasRole(user, ROLE_MEMBER));
        assertFalse(dao.hasRole(user, ROLE_PROPOSER));
    }

    function testGetRoles() public {
        bytes4[] memory roles = dao.getRolesList();

        assertEq(roles[0], ROLE_MEMBER);
        assertEq(roles[1], ROLE_ADMIN);
        assertEq(roles[2], ROLE_PROPOSER);
    }
}
