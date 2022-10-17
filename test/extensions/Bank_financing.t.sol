// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "test/base/BaseTest.sol";

contract Bank_financing_test is BaseTest {
    using stdStorage for StdStorage;
    IDaoCore public core;
    IERC20 public token;
    Bank public bank;

    address public constant TOKEN_ADDRESS = address(0xee);
    address public constant CORE = address(0xff);

    address public constant FINANCING = address(uint160(uint32(Slot.FINANCING)));
    address public constant APPLICANT = address(0x0f);
    address public constant NOT_RIGHT_ADAPTER = address(0x0e);

    bytes32 public constant PROPOSAL = keccak256(abi.encode("a proposal"));
    bytes32 public constant ANOTHER_PROPOSAL = keccak256(abi.encode("another proposal"));

    function setUp() public override {
        super.setUp();
        token = ERC20_REVERTS(TOKEN_ADDRESS);
        core = IDaoCore(CORE);
        bank = new Bank(address(core), address(token));

        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.FINANCING),
            abi.encode(FINANCING)
        );
    }

    function testSetFinancingProposalData() public {
        // SETUP
        uint256 amount = 10**20;
        /////////////

        assertEq(bank.vaultsBalance(Slot.TREASURY), 0);
        assertEq(bank.financingProposalsBalance(PROPOSAL), 0);

        vm.prank(NOT_RIGHT_ADAPTER);
        vm.expectRevert("CoreGuard: not the right adapter");
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount);
        assertEq(bank.vaultsBalance(Slot.TREASURY), amount);
        assertEq(bank.financingProposalsBalance(PROPOSAL), amount);

        (uint256 slot, bytes32 value) = retrieveSlotAndValue(
            address(bank),
            "vaultsBalance(bytes4)",
            BaseTest.Key("bytes4", bytes32(Slot.TREASURY))
        );
        console.log("vaultsBalance(Slot.TREASURY)");
        console.log(slot);
        console.logBytes32(value);

        vm.stopPrank();
        vm.clearMockedCalls();
    }

    function testExecuteFinancingProposal_reverts() public {
        // SETUP
        uint256 amount = 10**20;

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount);

        bytes memory data = abi.encodeWithSelector(
            core.getSlotContractAddr.selector,
            Slot.FINANCING
        );
        vm.mockCall(address(core), data, abi.encode(FINANCING));
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, address(bank)),
            abi.encode(amount)
        );
        /////////////////////

        vm.prank(NOT_RIGHT_ADAPTER);
        vm.expectCall(address(core), data);
        vm.expectRevert("CoreGuard: not the right adapter");
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

        vm.prank(FINANCING);
        vm.expectCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, address(bank))
        );
        vm.expectRevert("Bank: insufficient funds in bank");
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount + 10);

        vm.stopPrank();
        vm.clearMockedCalls();
    }

    function testExecuteFinancingProposal_revert_vault_balance() public {
        // SETUP
        uint256 amount = 10**20;

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount - 10);

        bytes memory data = abi.encodeWithSelector(
            core.getSlotContractAddr.selector,
            Slot.FINANCING
        );
        vm.mockCall(address(core), data, abi.encode(FINANCING));
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, address(bank)),
            abi.encode(amount)
        );
        /////////////////////

        vm.prank(FINANCING);
        vm.expectCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, address(bank))
        );
        vm.expectRevert("Bank: bad financing proposals balance");
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

        vm.stopPrank();
        vm.clearMockedCalls();
    }

    function testExecuteFinancingProposal_transfer_revert() public {
        // SETUP
        uint256 amount = 10**20;

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount);

        bytes memory data = abi.encodeWithSelector(
            core.getSlotContractAddr.selector,
            Slot.FINANCING
        );
        // Mocked calls
        vm.mockCall(address(core), data, abi.encode(FINANCING));
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, address(bank)),
            abi.encode(amount)
        );
        /////////////////////

        vm.prank(FINANCING);
        vm.expectCall(address(token), abi.encodeCall(token.transfer, (APPLICANT, amount)));
        vm.expectRevert();
        bool success = bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);
        assertFalse(success);
        assertEq(bank.vaultsBalance(Slot.TREASURY), amount);
        assertEq(bank.financingProposalsBalance(PROPOSAL), amount);

        vm.stopPrank();
        vm.clearMockedCalls();
    }

    // tested even if transfer does not return false but only true or revert
    function testExecuteFinancingProposal_return_false() public {
        // SETUP
        uint256 amount = 10**20;

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount);

        bytes memory data = abi.encodeWithSelector(
            core.getSlotContractAddr.selector,
            Slot.FINANCING
        );
        // Mocked calls
        vm.mockCall(address(core), data, abi.encode(FINANCING));
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, address(bank)),
            abi.encode(amount)
        );
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transfer.selector, APPLICANT, amount),
            abi.encode(false)
        );
        /////////////////////

        vm.prank(FINANCING);
        vm.expectCall(address(token), abi.encodeCall(token.transfer, (APPLICANT, amount)));
        vm.expectRevert("Bank: transfer failed");
        bool success = bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);
        assertFalse(success);
        assertEq(bank.vaultsBalance(Slot.TREASURY), amount);
        assertEq(bank.financingProposalsBalance(PROPOSAL), amount);

        vm.stopPrank();
        vm.clearMockedCalls();
    }

    function testExecuteFinancingProposal_return_true() public {
        // SETUP
        uint256 amount = 10**20;

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount);

        bytes memory data = abi.encodeWithSelector(
            core.getSlotContractAddr.selector,
            Slot.FINANCING
        );
        // Mocked calls
        vm.mockCall(address(core), data, abi.encode(FINANCING));
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, address(bank)),
            abi.encode(amount)
        );
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transfer.selector, APPLICANT, amount),
            abi.encode(true)
        );
        /////////////////////

        vm.prank(FINANCING);

        vm.expectCall(address(token), abi.encodeCall(token.transfer, (APPLICANT, amount)));
        bool success = bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);
        assertTrue(success);
        assertEq(bank.vaultsBalance(Slot.TREASURY), 0);
        assertEq(bank.financingProposalsBalance(PROPOSAL), 0);

        vm.stopPrank();
        vm.clearMockedCalls();
    }
}
