// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "src/helpers/Slot.sol";
import "src/core/DaoCore.sol";
import "src/core/IDaoCore.sol";
import "src/extensions/Bank.sol";
import "test/base/ERC20_reverts.sol";

abstract contract BaseTest is Test {
    using stdStorage for StdStorage;
    mapping(address => uint256) writesLengths;
    mapping(address => uint256) readsLengths;

    function setUp() public virtual {}

    struct Key {
        string keyType;
        bytes32 keyValue;
    }

    function retrieveSlotAndValue(
        address target,
        string memory selector,
        Key memory key0
    ) public returns (uint256, bytes32 value) {
        Key[5] memory keys; // fixed size to avoid error
        keys[0] = key0;

        StdStorage storage store = stdstore.target(target).sig(selector);

        for (uint8 i = 0; i < keys.length; i++) {
            if (keccak256(abi.encode(keys[0].keyType)) == keccak256(abi.encode("uint256"))) {
                store = store.with_key(uint256(keys[0].keyValue));
            } else if (keccak256(abi.encode(keys[0].keyType)) == keccak256(abi.encode("bytes32"))) {
                store = store.with_key(keys[0].keyValue);
            } else if (keccak256(abi.encode(keys[0].keyType)) == keccak256(abi.encode("bytes4"))) {
                store = store.with_key(bytes4(keys[0].keyValue));
            } else {}
        }

        uint256 slot = store.find();

        return (slot, vm.load(target, bytes32(slot)));
    }

    // to use with vm.record();
    function storageActions(address contractAddress) public {
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(contractAddress);

        if (
            writes.length == writesLengths[contractAddress] &&
            reads.length == readsLengths[contractAddress]
        ) {
            console.log("nothing written or read");
            return;
        }

        if (writes.length > writesLengths[contractAddress]) {
            for (uint256 i = 0; i < writes.length - writesLengths[contractAddress]; i++) {
                console.log(
                    "@slot:%s write %s",
                    uint256(writes[i]),
                    uint256(vm.load(contractAddress, writes[i]))
                );
            }
        }

        if (reads.length > readsLengths[contractAddress]) {
            for (uint256 i = 0; i < reads.length - readsLengths[contractAddress]; i++) {
                console.log(
                    "@slot:%s read %s",
                    uint256(reads[i]),
                    uint256(vm.load(contractAddress, reads[i]))
                );
            }
        }

        writesLengths[contractAddress] = writes.length;
        readsLengths[contractAddress] = reads.length;
    }

    // to use with vm.record();
    function writeAccesses(address contractAddress) public {
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(contractAddress);
        for (uint256 i = 0; i < reads.length; i++) {
            console.log(
                "%s:read %s @slot:%s",
                i,
                uint256(vm.load(contractAddress, reads[i])),
                uint256(reads[i])
            );
        }
        for (uint256 i = 0; i < writes.length; i++) {
            console.log(
                "%s:write %s @slot:%s",
                i,
                uint256(vm.load(contractAddress, writes[i])),
                uint256(writes[i])
            );
        }
    }

    function readSlots(address contractAddress) public {
        bytes32 value;
        uint256 i;
        while ((value = vm.load(contractAddress, bytes32(i))) != bytes32(0)) {
            console.log("value@slot[%s] = %s", i, uint256(vm.load(contractAddress, bytes32(i))));
            i++;
        }
    }

    function readSlots(address contractAddress, uint256 length) public {
        for (uint256 i = 0; i < length; i++) {
            console.log("value@slot[%s] = %s", i, uint256(vm.load(contractAddress, bytes32(i))));
        }
    }
}
