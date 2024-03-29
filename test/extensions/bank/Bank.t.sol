// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "test/base/BaseDaoTest.sol";
import "src/extensions/Bank.sol";

contract Bank_test is BaseDaoTest {
    Bank public bank;

    address public constant USER = address(502);
    // bytes32[5] public PROPOSAL =

    address public BANK;
    address public VOTING;
    address public FINANCING;

    address public constant APPLICANT = address(0x0f);
    address public constant NOT_RIGHT_ADAPTER = address(0x0e);

    bytes4 public constant VAULT_TREASURY = bytes4(keccak256(bytes("vault-treasury")));
    bytes32 public constant PROPOSAL = keccak256(abi.encode("a proposal"));

    function setUp() public {
        _deployDao(address(501));
        _deployTBIO();
        bank = new Bank(address(dao), address(tbio));
        BANK = address(bank);
        _branch(Slot.BANK, BANK);
        VOTING = _branchMock(Slot.VOTING, false);
        FINANCING = _branchMock(Slot.FINANCING, false);
    }

    enum LockPeriod {
        P1,
        P7,
        P15,
        P30,
        P120,
        P365
    }

    function workaround_lpToUint(LockPeriod lp) internal pure returns (uint32) {
        if (lp == LockPeriod.P1) {
            return 1 days;
        } else if (lp == LockPeriod.P7) {
            return 7 days;
        } else if (lp == LockPeriod.P15) {
            return 15 days;
        } else if (lp == LockPeriod.P30) {
            return 30 days;
        } else if (lp == LockPeriod.P120) {
            return 120 days;
        } else if (lp == LockPeriod.P365) {
            return 365 days;
        } else {
            return 0;
        }
    }

    function workaround_lpMultiplier(LockPeriod lp, uint96 tokenAmount)
        internal
        pure
        returns (uint96)
    {
        if (lp == LockPeriod.P1) {
            return tokenAmount / 10;
        } else if (lp == LockPeriod.P7) {
            return tokenAmount;
        } else if (lp == LockPeriod.P15) {
            return tokenAmount * 2;
        } else if (lp == LockPeriod.P30) {
            return tokenAmount * 4;
        } else if (lp == LockPeriod.P120) {
            return tokenAmount * 25;
        } else if (lp == LockPeriod.P365) {
            return tokenAmount * 50;
        } else {
            revert("Bank: incorrect lock period");
        }
    }

    function test_newCommitment_NewCommitment(uint256 tokenAmount, uint8 enumLP) public {
        vm.assume(tokenAmount > 0 && tokenAmount <= 50_000e18 && enumLP < 6);
        LockPeriod lp = LockPeriod(enumLP);
        vm.warp(1000);

        _mintTBIO(USER, tokenAmount);
        vm.prank(USER);
        tbio.approve(BANK, tokenAmount);

        vm.prank(VOTING);
        bank.newCommitment(USER, bytes32("0x01"), uint96(tokenAmount), workaround_lpToUint(lp), 0);

        assertEq(tbio.balanceOf(BANK), tokenAmount);

        (uint96 lockedAmount, uint96 voteWeight, uint32 lockPeriod, uint32 retrievalDate) = bank
            .getCommitment(USER, bytes32("0x01"));
        assertEq(lockedAmount, tokenAmount, "lock amount");
        assertEq(voteWeight, workaround_lpMultiplier(lp, uint96(tokenAmount)), "vote weight");
        assertEq(lockPeriod, workaround_lpToUint(lp), "lock period");
        assertEq(retrievalDate, 1000 + workaround_lpToUint(lp), "retrieval date");

        assertEq(bank.getCommitmentsList(USER).length, 1);
        assertEq(bank.getCommitmentsList(USER)[0], bytes32("0x01"));

        (uint128 availableBalance, uint128 lockedBalance) = bank.getBalances(USER);
        assertEq(availableBalance, 0);
        assertEq(lockedBalance, tokenAmount);

        assertEq(bank.getNextRetrievalDate(USER), 1000 + workaround_lpToUint(lp));
    }

    function test_newCommitment_CannotSomeReasons() public {
        vm.warp(1000);

        vm.prank(VOTING);
        vm.expectRevert("ERC20: insufficient allowance");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50e18), 7 days, 0);

        vm.prank(USER);
        tbio.approve(BANK, 50e18);

        vm.prank(VOTING);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50e18), 7 days, 0);

        _mintTBIO(USER, 50e18);
        vm.expectRevert("Cores: not the right adapter");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50e18), 7 days, 0);

        vm.prank(VOTING);
        bank.newCommitment(USER, bytes32("0x01"), uint96(50e18), 7 days, 0);

        vm.prank(VOTING);
        vm.expectRevert("Bank: already committed");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50e18), 7 days, 0);
    }

    // function testMultipleNewCommitment() public {
    //     //
    // }

    // function testEndOfCommitment() public {
    //     //
    // }

    // function testUseAvailableBalanceWhenCommitment() public {
    //     //
    // }

    // function testGetFuturesBalance() public {
    //     // try to get the real available balance and match it with a newCommitment to confirm
    //     //
    // }

    // function testGetFutureNextRetrieval() public {
    //     // same as above
    //     //
    // }

    // // withdrawAmount()
    // function testWithdrawAmount() public {
    //     //
    // }

    // function testCannotWithdrawAmount() public {
    //     //
    // }

    // adancedDeposit()
    function test_advancedDeposit_Deposit() public {
        _mintTBIO(USER, 50e18);
        vm.prank(USER);
        tbio.approve(BANK, 50e18);

        vm.prank(VOTING);
        bank.advancedDeposit(USER, uint128(50e18));

        (uint128 availableBalance, ) = bank.getBalances(USER);
        assertEq(availableBalance, uint128(50e18));
    }

    function test_advancedDeposit_CannotWhenNotAuthorized() public {
        vm.expectRevert(); // without message (wrong call)
        bank.advancedDeposit(USER, uint128(50e18));

        // with an unregistred adapter
        address fakeEntry = _newEntry(Slot.ONBOARDING, false);
        vm.prank(fakeEntry);
        vm.expectRevert("Cores: not the right adapter");
        bank.advancedDeposit(USER, uint128(50e18));
    }

    // createVault()
    function workaround_createVault(address[] memory a) internal {
        vm.prank(FINANCING);
        bank.createVault(VAULT_TREASURY, a);
    }

    function test_createVault_NewVault() public {
        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        workaround_createVault(a);

        assertTrue(bank.isVaultExist(VAULT_TREASURY));
        address[] memory addr = bank.getVaultTokenList(VAULT_TREASURY);
        assertEq(addr.length, 2);
        assertEq(addr[0], address(0));
        assertEq(addr[1], address(tbio));
    }

    function test_createVault_CannotWhenAlreadyExist() public {
        address[] memory a = new address[](4);
        a[0] = address(0);
        a[1] = address(tbio);
        workaround_createVault(a);

        a[0] = address(0);
        a[1] = address(1);
        a[2] = address(2);
        a[3] = address(3);

        vm.expectRevert("Bank: vault already exist");
        vm.prank(FINANCING);
        bank.createVault(VAULT_TREASURY, a);
    }

    function test_vaultDeposit_Deposit(uint256 tokenAmount) public {
        vm.assume(tokenAmount > 0 && tokenAmount < type(uint128).max);
        _mintTBIO(USER, tokenAmount);
        vm.prank(USER);
        tbio.approve(BANK, tokenAmount);

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        workaround_createVault(a);

        vm.prank(FINANCING);
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, uint128(tokenAmount));

        assertEq(tbio.balanceOf(USER), 0);
        assertEq(tbio.balanceOf(BANK), tokenAmount);
        (uint128 availableBalance, ) = bank.getVaultBalances(VAULT_TREASURY, address(tbio));
        assertEq(uint256(availableBalance), tokenAmount);
    }

    function test_vaultDeposit_CannotWrongTokenAndVault() public {
        uint128 tokenAmount = uint128(50e18);
        _mintTBIO(USER, tokenAmount);
        vm.prank(USER);
        tbio.approve(BANK, tokenAmount);

        vm.prank(FINANCING);
        vm.expectRevert("Bank: inexistant vaultId");
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, uint128(tokenAmount));

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(5);
        workaround_createVault(a);

        vm.prank(FINANCING);
        vm.expectRevert("Bank: unregistred token");
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, uint128(tokenAmount));
    }

    // newFinancingProposal()
    /*function testNewFinancingProposal(uint128 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        _mintTBIO(USER, amount);
        vm.prank(USER);
        tbio.approve(BANK, amount);

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        workaround_createVault(a);

        vm.prank(FINANCING);
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, amount);

        vm.prank(FINANCING);
        bank.newFinancingProposal(VAULT_TREASURY, address(tbio), amount);

        (uint128 availableBalance, uint128 committedBalance) = bank.getVaultBalances(
            VAULT_TREASURY,
            address(tbio)
        );

        assertEq(availableBalance, 0);
        assertEq(committedBalance, amount);
    }

    function testCannotNewFinancingProposal(uint128 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        _mintTBIO(USER, amount);
        vm.prank(USER);
        tbio.approve(BANK, amount);

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        workaround_createVault(a);

        vm.startPrank(FINANCING);
        vm.expectRevert("Bank: inexistant vaultId");
        bank.newFinancingProposal(bytes4("0x01"), address(tbio), amount);

        vm.expectRevert("Bank: not enough in the vault");
        bank.newFinancingProposal(VAULT_TREASURY, address(tbio), amount);
    }

    function testExecuteFinancingProposal(uint128 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        _mintTBIO(USER, amount);
        vm.prank(USER);
        tbio.approve(BANK, amount);

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        workaround_createVault(a);

        vm.startPrank(FINANCING);
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, amount);

        bank.newFinancingProposal(VAULT_TREASURY, address(tbio), amount);

        address destination = address(5);
        bank.executeFinancingProposal(VAULT_TREASURY, address(tbio), destination, amount);

        assertEq(tbio.balanceOf(destination), amount);
        (uint128 availableBalance, uint128 committedBalance) = bank.getVaultBalances(
            VAULT_TREASURY,
            address(tbio)
        );
        assertEq(availableBalance, 0);
        assertEq(committedBalance, 0);
    }*/
}
