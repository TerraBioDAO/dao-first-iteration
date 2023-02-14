// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import { Storage } from "src/Storage.sol";
import { Impl } from "src/Impl.sol";

contract logs is Script, Test {
    using stdJson for string;

    function run() public {
        emit log_string("Hello Dao builder!");
        // logs something here

        Storage s = new Storage();
        s.fill();

        // log slots
        emit log_string("\n--- Contract slots ---");
        // a
        emit log_named_bytes32("Slot 00", vm.load(address(s), bytes32(abi.encode(0))));
        // b
        emit log_named_bytes32("Slot 01", vm.load(address(s), bytes32(abi.encode(1))));
        // c
        emit log_named_bytes32("Slot 02", vm.load(address(s), bytes32(abi.encode(2))));
        emit log_named_bytes32("Slot 03", vm.load(address(s), bytes32(abi.encode(3))));
        emit log_named_bytes32("Slot 04", vm.load(address(s), bytes32(abi.encode(4))));
        emit log_named_bytes32("Slot 05", vm.load(address(s), bytes32(abi.encode(5))));
        emit log_named_bytes32("Slot 06", vm.load(address(s), bytes32(abi.encode(6))));
        // d
        emit log_named_bytes32("Slot 07", vm.load(address(s), bytes32(abi.encode(7))));
        // e
        emit log_named_bytes32("Slot 08", vm.load(address(s), bytes32(abi.encode(8))));

        emit log_string("\n--- Lookup slots (Array) ---");
        // to slot d
        uint256 hd = uint256(keccak256(abi.encode(7)));
        emit log_named_bytes32("Slot h(7)", vm.load(address(s), bytes32(hd)));
        emit log_named_bytes32("Slot h(7)+1", vm.load(address(s), bytes32(hd + 1)));
        emit log_named_bytes32("Slot h(7)+2", vm.load(address(s), bytes32(hd + 2)));
        emit log_named_bytes32("Slot h(7)+3", vm.load(address(s), bytes32(hd + 3)));
        emit log_named_bytes32("Slot h(7)+4", vm.load(address(s), bytes32(hd + 4)));

        emit log_string("\n--- Lookup slots (Mapping) ---");
        // to slot e
        bytes32 key = keccak256("a");
        uint256 he = uint256(keccak256(bytes.concat(abi.encode(key), abi.encode(8))));
        emit log_named_bytes32("Slot h(key.8)", vm.load(address(s), bytes32(he)));

        emit log_string("\n--- Lookup slots (Custom slot) ---");
        // slot 21000
        emit log_named_bytes32("Slot 21000", vm.load(address(s), bytes32(abi.encode(21000))));
        emit log_named_bytes32("Slot 21001", vm.load(address(s), bytes32(abi.encode(21001))));

        // call and delegatecall
        vm.startPrank(address(5));
        s = new Storage();
        Impl impl = new Impl();
        vm.label(address(s), "STORAGE");
        vm.label(address(impl), "IMPL");
        vm.label(address(5), "CALLER");

        emit log_string("\n--- Call & delegatecall ---");
        emit log_string("\n--- Initialisation ---");
        // Storage
        emit log_named_bytes32("Storage:slot 00", vm.load(address(s), bytes32(abi.encode(0))));
        emit log_named_bytes32("Storage:slot 01", vm.load(address(s), bytes32(abi.encode(1))));
        emit log_named_bytes32("Impl:slot 00", vm.load(address(impl), bytes32(abi.encode(0))));
        emit log_named_bytes32("Impl:slot 01", vm.load(address(impl), bytes32(abi.encode(1))));

        s.callWriteSlot0(address(impl));
        s.callWriteSlot1(address(impl));

        emit log_string("\n--- Call implementation ---");
        emit log_named_bytes32("Storage:slot 00", vm.load(address(s), bytes32(abi.encode(0))));
        emit log_named_bytes32("Storage:slot 01", vm.load(address(s), bytes32(abi.encode(1))));
        emit log_named_bytes32("Impl:slot 00", vm.load(address(impl), bytes32(abi.encode(0))));
        emit log_named_bytes32("Impl:slot 01", vm.load(address(impl), bytes32(abi.encode(1))));

        s.delegatecallWriteSlot0(address(impl));
        s.delegatecallWriteSlot1(address(impl));

        emit log_string("\n--- DelegateCall implementation ---");
        emit log_named_bytes32("Storage:slot 00", vm.load(address(s), bytes32(abi.encode(0))));
        emit log_named_bytes32("Storage:slot 01", vm.load(address(s), bytes32(abi.encode(1))));
        emit log_named_bytes32("Impl:slot 00", vm.load(address(impl), bytes32(abi.encode(0))));
        emit log_named_bytes32("Impl:slot 01", vm.load(address(impl), bytes32(abi.encode(1))));

        // emit event
        vm.recordLogs();
        s.delegateCallEvent(address(impl));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        emit log_named_uint("length", logs.length);
        emit log_named_bytes32("topic0", logs[0].topics[0]);
    }
}
