// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "test/base/BaseDaoTest.sol";
import "src/DaoCore.sol";
import "src/adapters/Managing.sol";

contract Managing_test is BaseDaoTest {
    Managing public managing;

    address public MANAGING;
    address public ENTRY = address(503);

    function setUp() public {
        _deployDao(address(501));
        managing = new Managing(DAO);
        MANAGING = address(managing);
        _branch(Slot.MANAGING, MANAGING);
    }

    function test_manageSlotEntry_AddEntry(bytes4 slot) public {
        vm.assume(slot != Slot.EMPTY);
        ENTRY = _newEntry(slot, false);

        vm.prank(ADMIN);
        managing.manageSlotEntry(slot, ENTRY);

        assertEq(dao.getSlotContractAddr(slot), ENTRY);
        assertTrue(dao.isSlotActive(slot));
        assertFalse(dao.isSlotExtension(slot));
    }

    function test_manageSlotEntry_CannotWhenNotAnAdmin(bytes4 slot) public {
        vm.assume(slot != Slot.EMPTY);

        ENTRY = _newEntry(slot, false);
        vm.expectRevert("Adapter: not an admin");
        managing.manageSlotEntry(slot, ENTRY);
    }
}
