// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";

contract FakeEntry {
    bytes4 public slotId;
    bool public isExtension;

    constructor(bytes4 slot, bool isExt) {
        slotId = slot;
        isExtension = isExt;
    }
}

contract DaoCore_test is Test {
    DaoCore public dao;

    address public constant ADMIN = address(0xAD);
    address public constant MANAGING = address(500);
    address public constant ONBOARDING = address(501);

    function _newEntry(bytes4 slot, bool isExt)
        internal
        returns (address entry)
    {
        entry = address(new FakeEntry(slot, isExt));
    }

    function setUp() public {
        vm.label(ADMIN, "Admin");
        vm.label(MANAGING, "Managing");
        vm.label(ONBOARDING, "Onboarding");

        dao = new DaoCore(ADMIN, MANAGING);
    }

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
        vm.expectRevert("CoreGuard: not the right adapter");
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);

        vm.prank(MANAGING);
        vm.expectRevert("Core: empty slot");
        dao.changeSlotEntry(Slot.EMPTY, ONBOARDING);
    }

    function testRemoveSlotEntry(bytes4 slot, address addr) public {
        vm.assume(
            slot != Slot.EMPTY && slot != Slot.MANAGING && addr != address(0)
        );
        addr = _newEntry(slot, false);
        vm.startPrank(MANAGING);
        dao.changeSlotEntry(slot, addr);
        dao.changeSlotEntry(slot, address(0));

        assertFalse(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), address(0));
        assertFalse(dao.isSlotExtension(slot));
    }

    function testReplaceSlotEntry(bytes4 slot, address addr) public {
        vm.assume(
            slot != Slot.EMPTY && slot != Slot.MANAGING && addr != address(0)
        );
        address fixedAddr = _newEntry(slot, false);
        addr = _newEntry(slot, false);

        vm.startPrank(MANAGING);
        dao.changeSlotEntry(slot, fixedAddr);
        dao.changeSlotEntry(slot, addr);

        assertTrue(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), addr);
        assertFalse(dao.isSlotExtension(slot));
    }

    function testCannotReplaceSlotEntry() public {
        // check when isExt != isExtension
    }
}
