// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

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

        _newUsersSet(0, 5);
        _setAsMembers();
        _mintTBIOForAll(1000e18);

        address[] memory tokenList = new address[](2);
        tokenList[1] = TBIO;
        vm.prank(ADMIN);
        financing.createVault(VAULT, tokenList);
    }

    function testCannotSubmitTransactionRequest() public {
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

    function testSubmitTransactionRequest() public {
        //
    }
}
