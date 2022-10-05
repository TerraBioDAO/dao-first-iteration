// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IBank {
    function joiningDeposit(address account, uint256 amount)
        external;

    function refundJoinDeposit(address account) external;
}
