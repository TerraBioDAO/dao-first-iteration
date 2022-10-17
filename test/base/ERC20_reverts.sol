// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract ERC20_REVERTS is IERC20 {
    function totalSupply() external pure returns (uint256) {
        revert();
    }

    function balanceOf(address account) external pure returns (uint256) {
        account == account;
        revert();
    }

    function allowance(address owner, address spender) external pure returns (uint256) {
        owner == owner;
        spender == spender;
        revert();
    }

    function approve(address spender, uint256 amount) external pure returns (bool) {
        amount == amount;
        spender == spender;
        revert();
    }

    function transfer(address to, uint256 amount) external pure returns (bool) {
        amount == amount;
        to == to;
        revert(); //revert("ERC20: transfer revert") doesn't work
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external pure returns (bool) {
        amount == amount;
        to == to;
        from == from;
        revert();
    }
}
