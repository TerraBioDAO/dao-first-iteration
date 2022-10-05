// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import "../helpers/Slot.sol";
import "../guards/CoreGuard.sol";

/**
 * @notice Should be the only contract to approve to move tokens
 *
 * Manage only the TBIO token
 */

contract Bank is CoreGuard, ReentrancyGuard {
    address public immutable terraBioToken;

    mapping(address => uint256) public balances;
    mapping(address => mapping(bytes4 => uint256)) public
        internalBalances;

    constructor(address core, address terraBioTokenAddr)
        CoreGuard(core, Slot.BANK)
    {
        terraBioToken = terraBioTokenAddr;
    }

    function joiningDeposit(address account, uint256 amount)
        external
        onlyAdapter(Slot.ONBOARDING)
    {
        _deposit(account, amount);
        _changeInternalBalance(
            account, Slot.CREDIT_VOTE, true, amount
        );
    }

    function refundJoinDeposit(address account)
        external
        nonReentrant
        onlyAdapter(Slot.ONBOARDING)
    {
        uint256 balance = balances[account];
        delete balances[account];
        IERC20(terraBioToken).transfer(account, balance);
        _changeInternalBalance(
            account, Slot.CREDIT_VOTE, false, balance
        );
    }

    function getBalanceOf(address account, bytes4 unit)
        external
        view
        returns (uint256)
    {
        if (unit == Slot.EMPTY) {
            return balances[account];
        } else {
            return internalBalances[account][unit];
        }
    }

    function _deposit(address account, uint256 amount) internal {
        IERC20(terraBioToken).transferFrom(
            account, address(this), amount
        );
        balances[account] += amount;
    }

    function _changeInternalBalance(
        address account,
        bytes4 unit,
        bool isDeposit,
        uint256 amount
    ) internal {
        uint256 balance = internalBalances[account][unit];
        if (!isDeposit) {
            require(amount <= balance, "Bank: insufficiant balance");
            internalBalances[account][unit] -= amount;
        } else {
            internalBalances[account][unit] += amount;
        }
    }
}
