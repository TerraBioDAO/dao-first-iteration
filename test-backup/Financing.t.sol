// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "test/base/BaseTest.sol";
import "test/reverts/Bank_reverts.sol";
import "src/adapters/Financing.sol";
import "src/adapters/Financing.sol";

contract Financing_test is BaseTest {
    using stdStorage for StdStorage;
    IDaoCore public core;
    IERC20 public token;
    IBank public bank;
    IAgora public agora;

    address public constant TOKEN_ADDRESS = address(0xee);
    address public constant CORE = address(0xff);
    address public constant AGORA = address(uint160(uint32(Slot.AGORA)));
    address public constant BANK = address(uint160(uint32(Slot.BANK)));

    address public constant PROPOSER = address(0x0d);
    address public constant APPLICANT = address(0x0f);
    address public constant NOT_RIGHT_ADAPTER = address(0x0e);

    bytes32 public constant PROPOSAL = keccak256(abi.encode("a proposal"));
    bytes32 public constant ANOTHER_PROPOSAL = keccak256(abi.encode("another proposal"));

    function setUp() public override {
        super.setUp();
        token = ERC20_reverts(TOKEN_ADDRESS);
        core = IDaoCore(CORE);
        bank = Bank_reverts(BANK);

        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.AGORA),
            abi.encode(AGORA)
        );
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.BANK),
            abi.encode(BANK)
        );

        // PROPOSER has USER_PROPOSER role
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, Slot.USER_PROPOSER),
            abi.encode(true)
        );

        // set financing proposal data
        vm.mockCall(
            address(bank),
            abi.encodeWithSelector(bank.setFinancingProposalData.selector),
            abi.encode(true) // useless for setter
        );

        // submit proposal to Agora
        vm.mockCall(
            address(bank),
            abi.encodeWithSelector(bank.submitProposal.selector),
            abi.encode(true) // useless for setter
        );
    }
}
