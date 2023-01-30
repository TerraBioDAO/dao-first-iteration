// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";
import "test/base/BaseDaoTest.sol";

/*
- Default to using `bound` to shape inputs: it increases the chance of testing the edges of your bound and is faster than `vm.assume`

- Use `vm.assume` to exclude specific values from fuzzing, such as an owner address
*/

contract DaoCore_test is BaseDaoTest {
    /// note DEPLOYER is granted as MANAGING & ONBOARDING at deployment
    address private constant DEPLOYER = address(777);
    address private constant USER = address(502);
    address private MANAGING;
    address private ONBOARDING;

    event MemberStatusChanged(
        address indexed member,
        bytes32 indexed roles,
        bool indexed actualValue
    );

    event SlotEntryChanged(
        bytes4 indexed slot,
        bool indexed isExtension,
        address oldContractAddr,
        address newContractAddr
    );

    function setUp() public {
        _deployDao(DEPLOYER);
    }

    /*///////////////////////////////
        POST DEPLOYMENT PROCESS
            - batch new members
            - batch new slots
    ///////////////////////////////*/
    function workaround_createBatchMemberArgs(uint256 addrOffset, uint256 length)
        private
        pure
        returns (
            address[] memory accounts,
            bytes32[] memory roles,
            bool[] memory values
        )
    {
        accounts = new address[](length);
        roles = new bytes32[](length);
        values = new bool[](length);
        for (uint256 i; i < length; i++) {
            accounts[i] = address(uint160(1 + addrOffset + i));
            roles[i] = ROLE_MEMBER;
            values[i] = true;
        }
    }

    function workaround_createBatchSlotArgs(uint256 length)
        private
        returns (bytes4[] memory slots, address[] memory contractsAddr)
    {
        slots = new bytes4[](length);
        contractsAddr = new address[](length);
        for (uint256 i; i < length; i++) {
            contractsAddr[i] = _newEntry(bytes4(uint32(i + 1)), false);
            slots[i] = bytes4(uint32(i + 1));
        }
    }

    /*///////////////////////////////
        batchChangeMembersStatus()
    ///////////////////////////////*/
    function test_batchChangeMembersStatus_VariousLenght(uint256 listLength) public {
        listLength = bound(listLength, 3, 100);

        for (uint256 i = 1; i < 10; i++) {
            (
                address[] memory accounts,
                bytes32[] memory roles,
                bool[] memory values
            ) = workaround_createBatchMemberArgs(i * 10000, listLength);
            vm.prank(DEPLOYER);
            dao.batchChangeMembersStatus(accounts, roles, values);
            assertEq(dao.membersCount(), (listLength * i) + 1);
        }
    }

    function test_batchChangeMembersStatus_CannotWithWrongList() public {
        address[] memory accounts = new address[](10);
        bytes32[] memory roles = new bytes32[](10);
        bool[] memory values = new bool[](9);

        vm.prank(DEPLOYER);
        vm.expectRevert("Core: list mismatch");
        dao.batchChangeMembersStatus(accounts, roles, values);
    }

    /*///////////////////////////////
        batchChangeSlotEntries()
    ///////////////////////////////*/
    function test_batchChangeSlotEntries_AddSeveralEntries() public {
        (bytes4[] memory slots, address[] memory contractsAddr) = workaround_createBatchSlotArgs(
            10
        );
        vm.prank(DEPLOYER);
        dao.batchChangeSlotEntries(slots, contractsAddr);

        for (uint256 i; i < slots.length; i++) {
            assertEq(dao.getSlotContractAddr(slots[i]), contractsAddr[i]);
        }
    }

    function test_batchChangeSlotEntries_CannotWithWrongList() public {
        bytes4[] memory slots = new bytes4[](5);
        address[] memory contractsAddr = new address[](6);

        vm.prank(DEPLOYER);
        vm.expectRevert("Core: list mismatch");
        dao.batchChangeSlotEntries(slots, contractsAddr);
    }

    /*///////////////////////////////
        changeSlotEntry(MANAGING)
        to finalize deployment
    ///////////////////////////////*/
    function test_changeSlotEntry_DeployerChangeManagingSlot() public {
        MANAGING = _newEntry(Slot.MANAGING, false);
        ONBOARDING = _newEntry(Slot.ONBOARDING, false);
        vm.startPrank(DEPLOYER);
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);
        dao.changeSlotEntry(Slot.MANAGING, MANAGING);

        assertEq(dao.getSlotContractAddr(Slot.ONBOARDING), ONBOARDING);
        assertEq(dao.getSlotContractAddr(Slot.MANAGING), MANAGING);
        assertEq(dao.legacyManaging(), DEPLOYER);
    }

    /*///////////////////////////////
            CHANGE MEMBER STATUS
    ///////////////////////////////*/
    function test_changeMemberStatus_ChangeSeveralStatus(bytes4 role) public {
        vm.assume(role != ROLE_MEMBER && role != ROLE_ADMIN);
        vm.startPrank(DEPLOYER);
        dao.changeMemberStatus(USER, role, true);
        assertTrue(dao.hasRole(USER, role));
        assertEq(dao.membersCount(), 1);

        dao.changeMemberStatus(USER, ROLE_MEMBER, true);
        assertTrue(dao.hasRole(USER, ROLE_MEMBER));
        assertEq(dao.membersCount(), 2);

        dao.changeMemberStatus(USER, ROLE_ADMIN, true);
        assertTrue(dao.hasRole(USER, ROLE_ADMIN));
        assertEq(dao.membersCount(), 2);
    }

    function test_changeMemberStatus_CannotWithZerAndWrongRole() public {
        vm.startPrank(DEPLOYER);
        vm.expectRevert("Core: zero address used");
        dao.changeMemberStatus(address(0), ROLE_MEMBER, true);

        vm.expectRevert("Core: role not affected");
        dao.changeMemberStatus(USER, ROLE_MEMBER, false);
        dao.changeMemberStatus(USER, ROLE_MEMBER, true);
        vm.expectRevert("Core: role not affected");
        dao.changeMemberStatus(USER, ROLE_MEMBER, true);
    }

    function test_changeMemberStatus_EmitEvent(bytes32 role, address user) public {
        vm.assume(user != address(0) && user != DEPLOYER);
        vm.startPrank(DEPLOYER);
        vm.expectEmit(true, true, true, false, DAO);
        emit MemberStatusChanged(user, role, true);
        dao.changeMemberStatus(user, role, true);
    }

    function test_changeMemberStatus_RevokeMember() public {
        vm.startPrank(DEPLOYER);
        dao.changeMemberStatus(USER, ROLE_MEMBER, true);
        dao.changeMemberStatus(USER, ROLE_ADMIN, true);
        assertEq(dao.membersCount(), 2);

        assertTrue(dao.hasRole(USER, ROLE_MEMBER));
        assertTrue(dao.hasRole(USER, ROLE_ADMIN));

        dao.changeMemberStatus(USER, ROLE_MEMBER, false);

        assertFalse(dao.hasRole(USER, ROLE_MEMBER));
        assertFalse(dao.hasRole(USER, ROLE_ADMIN));
        assertEq(dao.membersCount(), 1);
    }

    /*///////////////////////////////
            CHANGE SLOT ENTRY
    ///////////////////////////////*/
    function test_changeSlotEntry_AddSlotEntry(bytes4 slot, bool isExt) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.ONBOARDING && slot != Slot.MANAGING);
        address entry = _newEntry(slot, isExt);

        vm.prank(DEPLOYER);
        dao.changeSlotEntry(slot, entry);

        assertTrue(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), entry);
        assertEq(dao.isSlotExtension(slot), isExt);
    }

    function test_changeSlotEntry_CannotAddSlotEntry() public {
        ONBOARDING = address(600);
        vm.startPrank(DEPLOYER);

        vm.expectRevert("Core: empty slot");
        dao.changeSlotEntry(Slot.EMPTY, ONBOARDING);

        vm.expectRevert("Core: inexistant slotId() impl");
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);

        ONBOARDING = _newEntry(Slot.FINANCING, false);
        vm.expectRevert("Core: slot & address not match");
        dao.changeSlotEntry(Slot.ONBOARDING, ONBOARDING);
    }

    function test_changeSlotEntry_ReplaceSlotEntry(bytes4 slot, bool isExt) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.ONBOARDING && slot != Slot.MANAGING);
        address replacedEntry = _newEntry(slot, isExt);

        vm.startPrank(DEPLOYER);
        dao.changeSlotEntry(slot, replacedEntry);
        assertTrue(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), replacedEntry);
        assertEq(dao.isSlotExtension(slot), isExt);

        address entry = _newEntry(slot, isExt);
        dao.changeSlotEntry(slot, entry);
        assertEq(dao.getSlotContractAddr(slot), entry);
        assertEq(dao.isSlotExtension(slot), isExt);
    }

    function test_changeSlotEntry_CannotReplaceSlotEntry(bytes4 slot, bool isExt) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.ONBOARDING && slot != Slot.MANAGING);
        address replacedEntry = _newEntry(slot, isExt);

        vm.startPrank(DEPLOYER);
        dao.changeSlotEntry(slot, replacedEntry);

        address entry = _newEntry(slot, !isExt);
        vm.expectRevert("Core: slot type mismatch");
        dao.changeSlotEntry(slot, entry);
    }

    function test_changeSlotEntry_RemoveSlotEntry(bytes4 slot, bool isExt) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.ONBOARDING && slot != Slot.MANAGING);
        address entry = _newEntry(slot, isExt);

        vm.startPrank(DEPLOYER);
        dao.changeSlotEntry(slot, entry);
        dao.changeSlotEntry(slot, address(0));

        assertFalse(dao.isSlotActive(slot));
        assertEq(dao.getSlotContractAddr(slot), address(0));
        assertFalse(dao.isSlotExtension(slot));
    }

    function test_changeSlotEntry_ChangeManagingEntry() public {
        address firstManaging = _newEntry(Slot.MANAGING, false);
        vm.startPrank(DEPLOYER);
        dao.changeSlotEntry(Slot.MANAGING, firstManaging);
        assertEq(dao.legacyManaging(), DEPLOYER);
        assertEq(dao.getSlotContractAddr(Slot.MANAGING), firstManaging);

        address secondManaging = _newEntry(Slot.MANAGING, false);
        dao.changeSlotEntry(Slot.MANAGING, secondManaging);
        assertEq(dao.legacyManaging(), firstManaging);
        assertEq(dao.getSlotContractAddr(Slot.MANAGING), secondManaging);
    }

    function test_changeSlotEntry_CannotRemoveManaging() public {
        MANAGING = _newEntry(Slot.MANAGING, false);
        vm.startPrank(DEPLOYER);
        dao.changeSlotEntry(Slot.MANAGING, MANAGING);
        assertEq(dao.getSlotContractAddr(Slot.MANAGING), MANAGING);

        vm.expectRevert("Core: cannot remove Managing");
        dao.changeSlotEntry(Slot.MANAGING, address(0));
    }

    function test_changeSlotEntry_EmitEvent(bytes4 slot, bool isExt) public {
        vm.assume(slot != Slot.EMPTY && slot != Slot.ONBOARDING && slot != Slot.MANAGING);
        address firstEntry = _newEntry(slot, isExt);
        vm.startPrank(DEPLOYER);

        vm.expectEmit(true, true, false, true, DAO);
        emit SlotEntryChanged(slot, isExt, address(0), firstEntry);
        dao.changeSlotEntry(slot, firstEntry);

        address secondEntry = _newEntry(slot, isExt);
        vm.expectEmit(true, true, false, true, DAO);
        emit SlotEntryChanged(slot, isExt, firstEntry, secondEntry);
        dao.changeSlotEntry(slot, secondEntry);

        vm.expectEmit(true, true, false, true, DAO);
        emit SlotEntryChanged(slot, isExt, secondEntry, address(0));
        dao.changeSlotEntry(slot, address(0));
    }

    /*///////////////////////////////
                    ROLES
    ///////////////////////////////*/
    function test_constructor_RolesAtDeployment() public {
        assertTrue(dao.rolesActive(ROLE_MEMBER));
        assertTrue(dao.rolesActive(ROLE_ADMIN));
        assertEq(dao.getNumberOfRoles(), 2);
        assertEq(dao.getRolesByIndex(0), ROLE_MEMBER);
        assertEq(dao.getRolesByIndex(1), ROLE_ADMIN);
    }

    function test_addNewRole_AddRole(bytes32 role) public {
        vm.assume(role != ROLE_ADMIN && role != ROLE_MEMBER);
        vm.prank(DEPLOYER);
        dao.addNewRole(role);
        assertTrue(dao.rolesActive(role));
        assertEq(dao.getNumberOfRoles(), 3);
        assertEq(dao.getRolesByIndex(2), role);
    }

    function test_addNewRole_RemoveRole() public {
        vm.prank(DEPLOYER);
        dao.removeRole(ROLE_MEMBER);
        assertFalse(dao.rolesActive(ROLE_MEMBER));
        assertEq(dao.getNumberOfRoles(), 1);
        assertEq(dao.getRolesByIndex(0), ROLE_ADMIN);
    }
}
