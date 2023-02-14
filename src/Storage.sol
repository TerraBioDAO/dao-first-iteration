// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract Storage {
    struct CustomSlotStorage {
        uint256 a;
        uint256 b;
    }

    // slot 0
    uint256 private _a;
    // slot 1
    bytes32 private _b;
    // slot 2 => 6
    uint256[5] private _c;
    // slot 7
    uint256[] private _d;
    // slot 8
    mapping(bytes32 => uint256) private _e;

    // v2

    // fill all above slots
    function fill() external {
        // slot 0
        _a = 0xaaa;
        // slot 1
        _b = keccak256("a");
        // slot 2
        _c[0] = 0xc;
        // slot 3
        _c[1] = 0xcc;
        // slot 4
        _c[2] = 0xccc;
        // slot 5
        _c[3] = 0xcccc;
        // slot 6
        _c[4] = 0xccccc;
        // slot 7
        uint256[] memory d = new uint256[](5);
        // slot ?? => ??+4
        d[0] = 0xd;
        d[1] = 0xdd;
        d[2] = 0xddd;
        d[3] = 0xdddd;
        d[4] = 0xddddd;
        _d = d;
        // slot ???
        _e[_b] = 0xeee;

        // write at slot 21000
        CustomSlotStorage storage css;
        assembly {
            css.slot := 21000
        }
        css.a = 0xa;
        css.b = 0xb;
    }

    // call & delegate call on "impl" contract
    function callWriteSlot0(address impl) external {
        impl.call(abi.encodeWithSignature("writeSlot0()"));
    }

    function callWriteSlot1(address impl) external {
        impl.call(abi.encodeWithSignature("writeSlot1()"));
    }

    function delegatecallWriteSlot0(address impl) external {
        impl.delegatecall(abi.encodeWithSignature("writeSlot0()"));
    }

    function delegatecallWriteSlot1(address impl) external {
        impl.delegatecall(abi.encodeWithSignature("writeSlot1()"));
    }

    function delegateCallEvent(address impl) external {
        impl.delegatecall(abi.encodeWithSignature("emitEvent()"));
    }
}
