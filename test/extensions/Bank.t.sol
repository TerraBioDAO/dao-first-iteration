// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "test/base/BaseDaoTest.sol";

contract Bank_test is BaseDaoTest {
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

    // newCommitment()
    enum LockPeriod {
        P1,
        P7,
        P15,
        P30,
        P120,
        P365
    }

    function _lpToUint(LockPeriod lp) internal pure returns (uint32) {
        if (lp == LockPeriod.P1) {
            return DAY;
        } else if (lp == LockPeriod.P7) {
            return 7 * DAY;
        } else if (lp == LockPeriod.P15) {
            return 15 * DAY;
        } else if (lp == LockPeriod.P30) {
            return 30 * DAY;
        } else if (lp == LockPeriod.P120) {
            return 120 * DAY;
        } else if (lp == LockPeriod.P365) {
            return 365 * DAY;
        } else {
            return 0;
        }
    }

    function _lpMultiplier(LockPeriod lp, uint96 tokenAmount) internal pure returns (uint96) {
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

    function testNewCommitment(uint256 tokenAmount, uint8 enumLP) public {
        vm.assume(tokenAmount > 0 && tokenAmount <= 50_000 && enumLP < 6);
        LockPeriod lp = LockPeriod(enumLP);
        vm.warp(1000);

        _mintTBIO(USER, tokenAmount * TOKEN);
        vm.prank(USER);
        tbio.approve(BANK, tokenAmount * TOKEN);

        vm.prank(VOTING);
        bank.newCommitment(USER, bytes32("0x01"), uint96(tokenAmount * TOKEN), _lpToUint(lp), 0);

        assertEq(tbio.balanceOf(BANK), tokenAmount * TOKEN);

        (uint96 lockedAmount, uint96 voteWeight, uint32 lockPeriod, uint32 retrievalDate) = bank
            .getCommitment(USER, bytes32("0x01"));
        assertEq(lockedAmount, tokenAmount * TOKEN, "lock amount");
        assertEq(voteWeight, _lpMultiplier(lp, uint96(tokenAmount * TOKEN)), "vote weight");
        assertEq(lockPeriod, _lpToUint(lp), "lock period");
        assertEq(retrievalDate, 1000 + _lpToUint(lp), "retrieval date");

        assertEq(bank.getCommitmentsList(USER).length, 1);
        assertEq(bank.getCommitmentsList(USER)[0], bytes32("0x01"));

        (uint128 availableBalance, uint128 lockedBalance) = bank.getBalances(USER);
        assertEq(availableBalance, 0);
        assertEq(lockedBalance, tokenAmount * TOKEN);

        assertEq(bank.getNextRetrievalDate(USER), 1000 + _lpToUint(lp));
    }

    function testCannotNewCommitment() public {
        vm.warp(1000);

        vm.prank(VOTING);
        vm.expectRevert("ERC20: insufficient allowance");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50 * TOKEN), 7 * DAY, 0);

        vm.prank(USER);
        tbio.approve(BANK, 50 * TOKEN);
        vm.prank(VOTING);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50 * TOKEN), 7 * DAY, 0);

        _mintTBIO(USER, 50 * TOKEN);
        vm.expectRevert("CoreGuard: not the right adapter");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50 * TOKEN), 7 * DAY, 0);

        vm.prank(VOTING);
        bank.newCommitment(USER, bytes32("0x01"), uint96(50 * TOKEN), 7 * DAY, 0);

        vm.prank(VOTING);
        vm.expectRevert("Bank: already committed");
        bank.newCommitment(USER, bytes32("0x01"), uint96(50 * TOKEN), 7 * DAY, 0);
    }

    function testMultipleNewCommitment() public {
        //
    }

    function testEndOfCommitment() public {
        //
    }

    function testUseAvailableBalanceWhenCommitment() public {
        //
    }

    function testGetFuturesBalance() public {
        // try to get the real available balance and match it with a newCommitment to confirm
        //
    }

    function testGetFutureNextRetrieval() public {
        // same as above
        //
    }

    // withdrawAmount()
    function testWithdrawAmount() public {
        //
    }

    function testCannotWithdrawAmount() public {
        //
    }

    // adancedDeposit()
    function testAdancedDeposit() public {
        _mintTBIO(USER, 50 * TOKEN);
        vm.prank(USER);
        tbio.approve(BANK, 50 * TOKEN);

        vm.prank(VOTING);
        bank.advancedDeposit(USER, uint128(50 * TOKEN));

        (uint128 availableBalance, ) = bank.getBalances(USER);
        assertEq(availableBalance, uint128(50 * TOKEN));
    }

    function testCannotAdancedDeposit() public {
        vm.expectRevert(); // without message (wrong call)
        bank.advancedDeposit(USER, uint128(50 * TOKEN));

        // with an unregistred adapter
        address fakeEntry = _newEntry(Slot.ONBOARDING, false);
        vm.prank(fakeEntry);
        vm.expectRevert("CoreGuard: not the right adapter");
        bank.advancedDeposit(USER, uint128(50 * TOKEN));
    }

    // createVault()
    function _createVault(address[] memory a) internal {
        vm.prank(FINANCING);
        bank.createVault(VAULT_TREASURY, a);
    }

    function testCreateVault() public {
        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        _createVault(a);

        assertTrue(bank.isVaultExist(VAULT_TREASURY));
        address[] memory addr = bank.getVaultTokenList(VAULT_TREASURY);
        assertEq(addr.length, 2);
        assertEq(addr[0], address(0));
        assertEq(addr[1], address(tbio));
    }

    function testCannotCreateVault() public {
        address[] memory a = new address[](4);
        a[0] = address(0);
        a[1] = address(tbio);
        _createVault(a);

        a[0] = address(0);
        a[1] = address(1);
        a[2] = address(2);
        a[3] = address(3);

        vm.expectRevert("Bank: vault already exist");
        vm.prank(FINANCING);
        bank.createVault(VAULT_TREASURY, a);
    }

    function testDepositVault(uint256 tokenAmount) public {
        vm.assume(tokenAmount > 0 && tokenAmount < type(uint128).max);
        _mintTBIO(USER, tokenAmount);
        vm.prank(USER);
        tbio.approve(BANK, tokenAmount);

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        _createVault(a);

        vm.prank(FINANCING);
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, uint128(tokenAmount));

        assertEq(tbio.balanceOf(USER), 0);
        assertEq(tbio.balanceOf(BANK), tokenAmount);
        (uint128 availableBalance, ) = bank.getVaultBalances(VAULT_TREASURY, address(tbio));
        assertEq(uint256(availableBalance), tokenAmount);
    }

    function testCannotDepositVault() public {
        uint128 tokenAmount = uint128(50 * TOKEN);
        _mintTBIO(USER, tokenAmount);
        vm.prank(USER);
        tbio.approve(BANK, tokenAmount);

        vm.prank(FINANCING);
        vm.expectRevert("Bank: inexistant vaultId");
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, uint128(tokenAmount));

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(5);
        _createVault(a);

        vm.prank(FINANCING);
        vm.expectRevert("Bank: unregistred token");
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, uint128(tokenAmount));
    }

    // newFinancingProposal()
    function testNewFinancingProposal(uint128 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        _mintTBIO(USER, amount);
        vm.prank(USER);
        tbio.approve(BANK, amount);

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        _createVault(a);

        vm.prank(FINANCING);
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, amount);

        vm.prank(FINANCING);
        bank.newFincancingProposal(VAULT_TREASURY, address(tbio), amount);

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
        _createVault(a);

        vm.startPrank(FINANCING);
        vm.expectRevert("Bank: inexistant vaultId");
        bank.newFincancingProposal(bytes4("0x01"), address(tbio), amount);

        vm.expectRevert("Bank: not enough in the vault");
        bank.newFincancingProposal(VAULT_TREASURY, address(tbio), amount);
    }

    function testExecuteFinancingProposal(uint128 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        _mintTBIO(USER, amount);
        vm.prank(USER);
        tbio.approve(BANK, amount);

        address[] memory a = new address[](2);
        a[0] = address(0);
        a[1] = address(tbio);
        _createVault(a);

        vm.startPrank(FINANCING);
        bank.vaultDeposit(VAULT_TREASURY, address(tbio), USER, amount);

        bank.newFincancingProposal(VAULT_TREASURY, address(tbio), amount);

        address destination = address(5);
        bank.executeFinancingProposal(VAULT_TREASURY, address(tbio), destination, amount);

        assertEq(tbio.balanceOf(destination), amount);
        (uint128 availableBalance, uint128 committedBalance) = bank.getVaultBalances(
            VAULT_TREASURY,
            address(tbio)
        );
        assertEq(availableBalance, 0);
        assertEq(committedBalance, 0);
    }
}
