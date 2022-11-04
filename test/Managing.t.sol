// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";
import "src/adapters/Managing.sol";

contract FakeEntry {
    bytes4 public slotId;
    bool public isExtension;

    constructor(bytes4 slot, bool isExt) {
        slotId = slot;
        isExtension = isExt;
    }
}

contract Managing_test is Test {
    DaoCore public dao;
    Managing public managing;

    address public constant ADMIN = address(0xAD);
    address public constant USER = address(502);
    address public MANAGING;
    address public ENTRY = address(503);

    function _newEntry(bytes4 slot, bool isExt) internal returns (address entry) {
        entry = address(new FakeEntry(slot, isExt));
    }

    function setUp() public {
        dao = new DaoCore(ADMIN);
        managing = new Managing(address(dao));

        vm.prank(ADMIN);
        dao.changeSlotEntry(Slot.MANAGING, address(managing));
    }

    function testManageSlotEntry(bytes4 slot) public {
        vm.assume(slot != Slot.EMPTY);
        ENTRY = _newEntry(slot, false);

        vm.prank(ADMIN);
        managing.manageSlotEntry(slot, ENTRY);

        assertEq(dao.getSlotContractAddr(slot), ENTRY);
        assertTrue(dao.isSlotActive(slot));
        assertFalse(dao.isSlotExtension(slot));
    }

    function testCannotManageSlotEntry(bytes4 slot) public {
        vm.assume(slot != Slot.EMPTY);

        ENTRY = _newEntry(slot, false);
        vm.expectRevert("Adapter: not an admin");
        managing.manageSlotEntry(slot, ENTRY);
    }
}
