// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/core/DaoCore.sol";
import "../src/extensions/Bank.sol";
import {MockERC20} from "./MockERC20.sol";

contract DaoCoreTest is Test {

    DaoCore public daoCore;
    Bank public bank;
    MockERC20 internal token;

    address public OWNER = address(501);
    address public MEMBER1 = address(502);
    address public EXTENSION_BANK = address(101);
    address public ADAPTER_MANAGING = address(201);
    address public ADAPTER_FINANCING = address(202);
    address public ADAPTER_ONBOARDING = address(203);

    function setUp() public {
        vm.prank(OWNER);
        token = new MockERC20();
        daoCore = new DaoCore(OWNER, ADAPTER_MANAGING);
        bank = new Bank(address(daoCore), address(token));
        vm.stopPrank();
        vm.startPrank(ADAPTER_MANAGING);
        daoCore.changeSlotEntry(Slot.ONBOARDING, ADAPTER_ONBOARDING, false);
        daoCore.changeSlotEntry(Slot.BANK, address(bank), true);
        vm.stopPrank();
    }

    function testMembersCount() public {
        vm.prank(MEMBER1);
        assertEq(daoCore.membersCount(), 1);
    }

    function testSlotExtension() public {
        vm.prank(MEMBER1);
        assertTrue(daoCore.isExtension());
        assertTrue(daoCore.isSlotExtension(Slot.BANK));
        assertFalse(daoCore.isSlotExtension(Slot.ONBOARDING));
    }

    function testHasRole() public {
        vm.startPrank(ADAPTER_MANAGING);
        assertTrue(daoCore.hasRole(OWNER, Slot.USER_ADMIN));
        assertTrue(daoCore.hasRole(OWNER, Slot.USER_EXISTS));
        assertFalse(daoCore.hasRole(ADAPTER_MANAGING, Slot.USER_ADMIN));
        assertFalse(daoCore.hasRole(ADAPTER_MANAGING, Slot.USER_EXISTS));
    }

    function testIsSlotActive() public {
        assertTrue(daoCore.isSlotActive(Slot.MANAGING));
        assertFalse(daoCore.isSlotActive(Slot.FINANCING));
    }

    function testGetSlotContractAddr() public {
        assertEq(daoCore.getSlotContractAddr(Slot.MANAGING), ADAPTER_MANAGING);
    }

    function testChangeSlotEntry() public {
        vm.startPrank(ADAPTER_MANAGING);
        assertFalse(daoCore.isSlotActive(Slot.FINANCING));
        //TODO comprendre le expect emit !?
        /*        vm.expectEmit(true, true, false, true);
                emit SlotEntryChanged(Slot.FINANCING, false, ADAPTER_FINANCING, ADAPTER_FINANCING);*/
        daoCore.changeSlotEntry(Slot.FINANCING, ADAPTER_FINANCING, false);
        assertTrue(daoCore.isSlotActive(Slot.FINANCING));
        assertEq(daoCore.getSlotContractAddr(Slot.FINANCING), ADAPTER_FINANCING);
    }

    function testChangeSlotEntry_revertIfWrongAdapter() public {
        vm.startPrank(OWNER);
        vm.expectRevert("CoreGuard: not the right adapter");
        daoCore.changeSlotEntry(Slot.FINANCING, ADAPTER_FINANCING, false);
    }

    function testChangeMemberStatus() public {
        vm.startPrank(ADAPTER_ONBOARDING);
        assertFalse(daoCore.hasRole(MEMBER1, Slot.USER_EXISTS));
        assertFalse(daoCore.hasRole(MEMBER1, Slot.USER_PROPOSER));
        daoCore.changeMemberStatus(MEMBER1, Slot.USER_EXISTS, true);
        assertTrue(daoCore.hasRole(MEMBER1, Slot.USER_EXISTS));
        daoCore.changeMemberStatus(MEMBER1, Slot.USER_PROPOSER, true);
        assertTrue(daoCore.hasRole(MEMBER1, Slot.USER_PROPOSER));
        assertEq(daoCore.membersCount(), 2);
        daoCore.changeMemberStatus(MEMBER1, Slot.USER_EXISTS, false);
        assertEq(daoCore.membersCount(), 1);

    }

    function testChangeMemberStatus_revertIfWrongAdapter() public {
        vm.startPrank(OWNER);
        vm.expectRevert("CoreGuard: not the right adapter");
        daoCore.changeMemberStatus(MEMBER1, Slot.USER_EXISTS, false);
    }


}
