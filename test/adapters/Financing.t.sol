// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "test/base/BaseDaoTest.sol";
import "src/adapters/Financing.sol";
import "src/extensions/Agora.sol";
import "src/extensions/Bank.sol";

contract Financing2_test is BaseDaoTest {
    Financing internal financing;
    Agora internal agora;
    Bank internal bank;
    address internal FINANCING;
    address internal BANK;
    address internal AGORA;
    address internal VOTING;

    address internal constant RECIPIENT = address(777);
    bytes4 internal constant VAULT = bytes4(keccak256("vault"));

    function setUp() public {
        _deployDao(address(501));
        _deployTBIO();

        financing = new Financing(DAO);
        agora = new Agora(DAO);
        bank = new Bank(DAO, TBIO);
        FINANCING = address(financing);
        BANK = address(bank);
        AGORA = address(agora);

        _branch(Slot.AGORA, AGORA);
        _branch(Slot.BANK, BANK);
        _branch(Slot.FINANCING, FINANCING);
        VOTING = _branchMock(Slot.VOTING, false);

        _newUsersSet(0, 5);
        _setAsMembers();
        _mintTBIOForAll(1000e18);

        address[] memory tokenList = new address[](2);
        tokenList[1] = TBIO;
        vm.prank(ADMIN);
        financing.createVault(VAULT, tokenList);
    }

    /* //////////////////////////
                 UTILS
    ////////////////////////// */
    function workaround_fillVault_TBIO(bytes4 vaultId, uint128 amount) internal {
        address filler = address(100);
        _mintTBIO(filler, amount);
        vm.startPrank(filler);
        tbio.approve(BANK, amount);
        financing.vaultDeposit(vaultId, TBIO, amount);
        vm.stopPrank();
    }

    /* //////////////////////////
                TESTS
    ////////////////////////// */
    function test_createVault_CannotWhenNotAnAdmin(bytes4 vaultId) public {
        vm.assume(vaultId != bytes4(0) && vaultId != VAULT);
        address[] memory tokenList = new address[](4);
        tokenList[1] = TBIO;
        tokenList[2] = address(1);
        tokenList[3] = address(2);
        vm.expectRevert("Adapter: not an admin");
        financing.createVault(vaultId, tokenList);
    }

    function test_vaultDeposit_Deposit(address user, uint128 amount) public {
        vm.assume(user != address(0) && user != BANK && amount > 0);
        _mintTBIO(user, amount);
        vm.prank(user);
        tbio.approve(BANK, amount);
        vm.prank(user);
        financing.vaultDeposit(VAULT, TBIO, amount);

        assertEq(tbio.balanceOf(BANK), amount);
        (uint128 balance, ) = bank.getVaultBalances(VAULT, TBIO);
        assertEq(balance, amount);
    }

    function test_submitTransactionRequest_CannotSomeReasons() public {
        vm.expectRevert("Adapter: not a member");
        financing.submitTransactionRequest(VOTE_STANDARD, 50e18, RECIPIENT, VAULT, TBIO, 0);

        vm.expectRevert("Financing: insufficiant amount");
        vm.prank(USERS[0]);
        financing.submitTransactionRequest(VOTE_STANDARD, 0, RECIPIENT, VAULT, TBIO, 0);

        vm.expectRevert("Bank: inexistant vaultId");
        vm.prank(USERS[0]);
        financing.submitTransactionRequest(VOTE_STANDARD, 50e18, RECIPIENT, bytes4("a"), TBIO, 0);

        vm.expectRevert("Bank: not enough in the vault");
        vm.prank(USERS[0]);
        financing.submitTransactionRequest(VOTE_STANDARD, 50e18, RECIPIENT, VAULT, TBIO, 0);
    }

    function test_submitTransactionRequest_SubmitTxRequest(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 1000e18);
        workaround_fillVault_TBIO(VAULT, 1000e18);

        vm.prank(USERS[0]);
        financing.submitTransactionRequest(VOTE_STANDARD, amount, USERS[1], VAULT, TBIO, 0);

        (uint128 availableBalance, uint128 committedBalance) = bank.getVaultBalances(VAULT, TBIO);
        assertEq(availableBalance, 1000e18 - amount);
        assertEq(committedBalance, amount);
    }

    function test_finalizeProposal_FinalizeAnyway(bool accepted) public {
        workaround_fillVault_TBIO(VAULT, 1000e18);

        vm.prank(USERS[0]);
        vm.recordLogs();
        financing.submitTransactionRequest(VOTE_STANDARD, 50e18, RECIPIENT, VAULT, TBIO, 0);
        bytes32 proposalId = bytes32(vm.getRecordedLogs()[1].data);
        emit log_bytes32(proposalId);
        assertTrue(agora.getProposal(proposalId).active);

        if (accepted) {
            vm.warp(agora.getVoteParams(VOTE_STANDARD).adminValidationPeriod + 100);
            vm.prank(VOTING);
            agora.submitVote(proposalId, USERS[0], 10e18, 0);
        }

        vm.warp(120 days);
        vm.prank(USERS[0]);
        financing.finalizeProposal(proposalId);

        if (accepted) {
            assertEq(tbio.balanceOf(BANK), 1000e18 - 50e18);
            assertEq(tbio.balanceOf(RECIPIENT), 50e18);
        } else {
            assertEq(tbio.balanceOf(BANK), 1000e18);
        }
    }
}
