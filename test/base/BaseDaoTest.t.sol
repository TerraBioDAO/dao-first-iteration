// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./BaseDaoTest.sol";

contract BaseDaoTest_test is BaseDaoTest {
    address public BANK;

    function setUp() public {
        _deployDao(address(501));
        BANK = _branchMock(Slot.BANK, true);
    }

    function testBranch() public {
        assertEq(dao.getSlotContractAddr(Slot.BANK), BANK);
    }
}
