// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "test/base/BaseDaoTest.sol";
import "src/extensions/Bank.sol";

contract Bank_test is BaseDaoTest {
    Bank public bank;

    address public constant USER = address(502);
    // bytes32[5] public PROPOSAL =

    address public VOTING;
    address public FINANCING;

    address public constant APPLICANT = address(0x0f);
    address public constant NOT_RIGHT_ADAPTER = address(0x0e);

    bytes32 public constant PROPOSAL = keccak256(abi.encode("a proposal"));

    function setUp() public {
        _deployDao(address(501));
        _deployTBIO();
        bank = new Bank(address(dao), address(tbio));
        _branch(Slot.BANK, address(bank));
        VOTING = _branchMock(Slot.VOTING, false);
        FINANCING = _branchMock(Slot.FINANCING, false);
    }

    // function testSetFinancingProposalData() public {
    //     // SETUP
    //     uint256 amount = 10**20;
    //     /////////////

    //     assertEq(bank.vaultsBalance(Slot.TREASURY), 0);
    //     assertEq(bank.financingProposalsBalance(PROPOSAL), 0);

    //     vm.prank(NOT_RIGHT_ADAPTER);
    //     vm.expectRevert("CoreGuard: not the right adapter");
    //     bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

    //     vm.prank(FINANCING);
    //     bank.setFinancingProposalData(PROPOSAL, amount);
    //     assertEq(bank.vaultsBalance(Slot.TREASURY), amount);
    //     assertEq(bank.financingProposalsBalance(PROPOSAL), amount);

    //     vm.stopPrank();
    // }

    // function testExecuteFinancingProposal() public {
    //     // SETUP
    //     uint256 amount = 10**20;
    //     tbio.mint(address(bank), amount);

    //     vm.prank(FINANCING);
    //     bank.setFinancingProposalData(PROPOSAL, amount);
    //     /////////////////////

    //     assertEq(tbio.balanceOf(address(bank)), amount);
    //     assertEq(tbio.balanceOf(APPLICANT), 0);

    //     vm.prank(NOT_RIGHT_ADAPTER);
    //     vm.expectRevert("CoreGuard: not the right adapter");
    //     bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

    //     vm.prank(FINANCING);
    //     vm.expectRevert("Bank: insufficient funds in bank");
    //     bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount + 10);

    //     vm.prank(FINANCING);
    //     bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

    //     assertEq(tbio.balanceOf(address(bank)), 0);
    //     assertEq(tbio.balanceOf(APPLICANT), amount);
    //     vm.stopPrank();
    // }

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
        tbio.approve(address(bank), tokenAmount * TOKEN);

        vm.prank(VOTING);
        bank.newCommitment(USER, bytes32("0x01"), uint96(tokenAmount * TOKEN), _lpToUint(lp), 0);

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
        tbio.approve(address(bank), 50 * TOKEN);
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
        tbio.approve(address(bank), 50 * TOKEN);

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
}
