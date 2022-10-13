// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/core/DaoCore.sol";
import "src/core/IDaoCore.sol";
import "src/extensions/Agora.sol";
import "src/extensions/IAgora.sol";
import "src/extensions/Bank.sol";
import "src/adapters/Voting.sol";
import "src/guards/CoreGuard.sol";
import "src/helpers/Slot.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract MockTBIO is ERC20, Ownable {
    constructor() ERC20("Mocked TBIO", "TBIO") {}

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}

contract MockDaoCore {
    function getSlotContractAddr(bytes4 slot) external view returns (address) {
        return slot == Slot.FINANCING ? address(uint160(uint32(Slot.FINANCING))) : address(0);
    }
}

contract Bank_test is Test {
    MockDaoCore public core;
    MockTBIO public tbio;
    Bank public bank;
    address public coreAddress = address(0xcc);

    address public constant ADMIN = address(0x01);
    address public constant FINANCING = address(uint160(uint32(Slot.FINANCING)));
    address public constant APPLICANT = address(0x0f);
    address public constant NOT_RIGHT_ADAPTER = address(0x0e);

    bytes32 public constant PROPOSAL = keccak256(abi.encode("a proposal"));

    function setUp() public {
        tbio = new MockTBIO();
        core = new MockDaoCore();
        bank = new Bank(address(core), address(tbio));
    }

    function testSetFinancingProposalData() public {
        // SETUP
        uint256 amount = 10**20;
        /////////////

        assertEq(bank.vaultsBalance(Vault.TREASURY), 0);
        assertEq(bank.financingProposalsBalance(PROPOSAL), 0);

        vm.prank(NOT_RIGHT_ADAPTER);
        vm.expectRevert("CoreGuard: not the right adapter");
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount);
        assertEq(bank.vaultsBalance(Vault.TREASURY), amount);
        assertEq(bank.financingProposalsBalance(PROPOSAL), amount);

        vm.stopPrank();
    }

    function testExecuteFinancingProposal() public {
        // SETUP
        uint256 amount = 10**20;
        tbio.mint(address(bank), amount);

        vm.prank(FINANCING);
        bank.setFinancingProposalData(PROPOSAL, amount);
        /////////////////////

        assertEq(tbio.balanceOf(address(bank)), amount);
        assertEq(tbio.balanceOf(APPLICANT), 0);

        vm.prank(NOT_RIGHT_ADAPTER);
        vm.expectRevert("CoreGuard: not the right adapter");
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

        vm.prank(FINANCING);
        vm.expectRevert("Bank: insufficient funds in bank");
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount + 10);

        vm.prank(FINANCING);
        bank.executeFinancingProposal(PROPOSAL, APPLICANT, amount);

        assertEq(tbio.balanceOf(address(bank)), 0);
        assertEq(tbio.balanceOf(APPLICANT), amount);
        vm.stopPrank();
    }
}
