// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Eventer } from "src/Lib.sol";

contract Impl {
    event WhoCall(address sender, address origin, address thisContract);
    // slot 0
    bytes32 private _a;
    // slot 1
    uint256 private _b;

    function writeSlot0() external {
        _a = hex"abcdef";
    }

    function writeSlot1() external {
        emit WhoCall(msg.sender, tx.origin, address(this));
        _b = 0xfedcba;
    }

    function emitEvent() external {
        Eventer.sayHey();
    }
}
