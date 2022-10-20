// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/access/Ownable.sol";
import "test/base/BaseTest.sol";

//import "src/StorageTester.sol";

contract StorageTester {
    // Keep same declaration with original contract
    struct Simple {
        uint256 key;
        address value;
    }

    uint256 private value; // slot 0

    mapping(uint256 => uint256) private map; // slot 1
    mapping(address => bytes32) private map2; // slot 2
    mapping(uint256 => mapping(address => bytes32)) private map3; // 3
    mapping(uint256 => Simple) private map4; // 4
    mapping(uint256 => mapping(address => Simple)) private map5; // 5

    //////// SETTERS /////////

    function setValue(uint256 a) public {
        value = a;
    }

    function setMap(uint256 a, uint256 b) public {
        map[a] = b;
    }

    function setMap2(address a, bytes32 b) public {
        map2[a] = b;
    }

    function setMap3(
        uint256 a,
        address b,
        bytes32 c
    ) public {
        map3[a][b] = c;
    }

    function setMap4Key(uint256 a, Simple memory s) public {
        Simple storage simple = map4[a];
        simple.key = s.key;
    }

    function setMap4Value(uint256 a, Simple memory s) public {
        Simple storage simple = map4[a];
        simple.value = s.value;
    }

    function setMap5Key(
        uint256 a,
        address b,
        Simple memory s
    ) public {
        Simple storage simple = map5[a][b];
        simple.key = s.key;
    }

    function setMap5Value(
        uint256 a,
        address b,
        Simple memory s
    ) public {
        Simple storage simple = map5[a][b];
        simple.value = s.value;
    }

    //////// GETTERS /////////

    function getValue() public view returns (uint256) {
        return value;
    }

    function getMap(uint256 a) public view returns (uint256) {
        return map[a];
    }

    function getMap2(address a) public view returns (bytes32) {
        return map2[a];
    }

    function getMap3(uint256 a, address b) public view returns (bytes32) {
        return map3[a][b];
    }

    function getMap4(uint256 a) public view returns (Simple memory) {
        return map4[a];
    }

    function getMap5(uint256 a, address b) public view returns (Simple memory) {
        return map5[a][b];
    }
}

contract StorageTester_test is BaseTest {
    using stdStorage for StdStorage;
    StorageTester public contractToTest;

    function setUp() public override {
        vm.record();
        contractToTest = new StorageTester();
    }

    function testValue() public {
        //////////////////////////////////////
        // uint256 private value;
        bytes32 rootSlot = 0; // mapping slot
        address contractAddress = address(contractToTest);

        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);
        assertEq(lastWrittenSlots.length, 0);

        //////////////////////////////////////
        uint256 inputValue = 1;
        contractToTest.setValue(inputValue);
        lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(uint256(retrievedValue), inputValue);

        console.log("uint256 value = 1");
        console.log(
            "@slot:%s => %s",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(vm.load(contractAddress, lastWrittenSlots[0])))
        );

        // retrieve with stdtore
        uint256 stdstoreSlot = stdstore.target(contractAddress).sig("getValue()").find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value, can retrieve value with vm.load(contractAddress, slot)
        bytes32 calculatedSlot = rootSlot;
        assertEq(lastWrittenSlots[0], calculatedSlot);
    }

    function testMap() public {
        //////////////////////////////////////
        // mapping(uint256 => uint256) private map;
        bytes32 rootSlot = bytes32(uint256(1)); // mapping slot
        address contractAddress = address(contractToTest);

        uint256 index = 0;
        uint256 inputValue = 7;
        contractToTest.setMap(index, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(uint256(retrievedValue), inputValue);

        console.log("map[0] = 7");
        console.log(
            "@slot:%s => %s",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(vm.load(contractAddress, lastWrittenSlots[0])))
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap(uint256)")
            .with_key(index)
            .find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value, can retrieve value with vm.load(contractAddress, slot)
        bytes32 slot = keccak256(abi.encode(uint256(index), rootSlot));
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap2() public {
        //////////////////////////////////////
        // mapping(address => bytes32) private map2; // slot 2
        bytes32 rootSlot = bytes32(uint256(2)); // mapping slot
        address contractAddress = address(contractToTest);

        address index = address(0);
        bytes32 inputValue = 0x000000000000000000000000000000000000000000000000000000000000009c;
        contractToTest.setMap2(index, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, inputValue);

        console.log("map2[address(0)] = 0x9c");
        console.log(
            "@slot:%s => %s (%s)",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue)),
            abi.decode(bytes.concat(retrievedValue), (uint256)) //uint256(retrievedValue)
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap2(address)")
            .with_key(index)
            .find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value
        bytes32 slot = keccak256(abi.encode(index, rootSlot));
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap2suite() public {
        //////////////////////////////////////
        // mapping(address => bytes32) private map2; // slot 2
        bytes32 rootSlot = bytes32(uint256(2)); // mapping slot
        address contractAddress = address(contractToTest);

        // other value
        address index = address(3);
        bytes32 inputValue = bytes32(uint256(5));
        contractToTest.setMap2(index, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, inputValue);

        console.log("map2[address(3)] = bytes32(uint256(5));");
        console.log(
            "@slot:%s => %s",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue))
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap2(address)")
            .with_key(index)
            .find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value
        bytes32 slot = keccak256(abi.encode(index, rootSlot));
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap3() public {
        //////////////////////////////////////
        // mapping(uint256 => mapping(address => bytes32)) private map3; // 3
        // map3[0][address(0)] = bytes32(uint256(156));
        bytes32 rootSlot = bytes32(uint256(3)); // mapping slot
        address contractAddress = address(contractToTest);

        uint256 index1 = 0;
        address index2 = address(0);
        bytes32 inputValue = bytes32(uint256(111));
        contractToTest.setMap3(index1, index2, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, inputValue);

        console.log("map3[0][address(0)] = bytes32(uint256(111))");
        console.log(
            "@slot:%s => %s (%s)",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue)),
            abi.decode(bytes.concat(retrievedValue), (uint256)) //uint256(retrievedValue)
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap3(uint256,address)")
            .with_key(index1)
            .with_key(index2)
            .find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value
        bytes32 slot = keccak256(abi.encode(index2, keccak256(abi.encode(index1, rootSlot))));
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap3Bis() public {
        //////////////////////////////////////
        // mapping(uint256 => mapping(address => bytes32)) private map3; // 3
        // map3[5][address(18)] = bytes32(uint256(15));
        bytes32 rootSlot = bytes32(uint256(3)); // mapping slot
        address contractAddress = address(contractToTest);

        uint256 index1 = 5;
        address index2 = address(uint160(uint256(18)));
        bytes32 inputValue = bytes32(uint256(15));
        contractToTest.setMap3(index1, index2, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, inputValue);

        console.log("map3[5][address(18)] = bytes32(uint256(15))");
        console.log(
            "@slot:%s => %s (%s)",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue)),
            abi.decode(bytes.concat(retrievedValue), (uint256)) //uint256(retrievedValue)
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap3(uint256,address)")
            .with_key(index1)
            .with_key(index2)
            .find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value
        bytes32 slot = keccak256(abi.encode(index2, keccak256(abi.encode(index1, rootSlot))));
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap4Key() public {
        //////////////////////////////////////
        // mapping(uint256 => Simple) private map4; // 4
        // map4[0].key = 156;
        bytes32 rootSlot = bytes32(uint256(4)); // mapping slot
        address contractAddress = address(contractToTest);

        uint256 index1 = 0;
        StorageTester.Simple memory inputValue = StorageTester.Simple(uint256(156), address(0));
        contractToTest.setMap4Key(index1, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, bytes32(inputValue.key));

        console.log("map4[0].key = 156");
        console.log(
            "@slot:%s => %s (%s)",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue)),
            abi.decode(bytes.concat(retrievedValue), (uint256)) //uint256(retrievedValue)
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap4(uint256)")
            .with_key(index1)
            .depth(0)
            .find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value
        bytes32 slot = keccak256(abi.encode(index1, rootSlot));
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap4Value() public {
        //////////////////////////////////////
        // mapping(uint256 => Simple) private map4; // 4
        // map4[0].value = address(501);
        bytes32 rootSlot = bytes32(uint256(4)); // mapping slot
        address contractAddress = address(contractToTest);

        uint256 index1 = 0;
        StorageTester.Simple memory inputValue = StorageTester.Simple(
            uint256(0),
            address(uint160(uint256(501)))
        );
        contractToTest.setMap4Value(index1, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, bytes32(uint256(uint160(inputValue.value))));

        console.log("map4[0].value = address(501)");
        console.log(
            "@slot:%s => %s (%s)",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue)),
            abi.decode(bytes.concat(retrievedValue), (uint256)) //uint256(retrievedValue)
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap4(uint256)")
            .with_key(index1)
            .find();

        uint256 shift = 1;
        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot + shift));

        // calculate slot value
        bytes32 slot = bytes32(uint256(keccak256(abi.encode(index1, rootSlot))) + shift);
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap5key() public {
        //////////////////////////////////////
        // mapping(uint256 => mapping(address => Simple)) private map5; // 5
        // map5[0][address(0)].key = 5744;
        bytes32 rootSlot = bytes32(uint256(5)); // mapping slot
        address contractAddress = address(contractToTest);

        uint256 index1 = 0;
        address index2 = address(0);
        StorageTester.Simple memory inputValue = StorageTester.Simple(uint256(5744), address(0));
        contractToTest.setMap5Key(index1, index2, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, bytes32(inputValue.key));

        console.log("map5[0][address(0)].key = 5744");
        console.log(
            "@slot:%s => %s (%s)",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue)),
            abi.decode(bytes.concat(retrievedValue), (uint256)) //uint256(retrievedValue)
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap5(uint256,address)")
            .with_key(index1)
            .with_key(index2)
            .find();

        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot));

        // calculate slot value
        bytes32 slot = keccak256(abi.encode(index2, keccak256(abi.encode(index1, rootSlot))));
        assertEq(lastWrittenSlots[0], slot);
    }

    function testMap5Value() public {
        //////////////////////////////////////
        // mapping(uint256 => mapping(address => Simple)) private map5; // 5
        // map5[10][address(18)].value = address(8881);
        bytes32 rootSlot = bytes32(uint256(5)); // mapping slot
        address contractAddress = address(contractToTest);

        uint256 index1 = 10;
        address index2 = address(uint160(uint256(18)));
        StorageTester.Simple memory inputValue = StorageTester.Simple(
            uint256(0),
            address(uint160(uint256(8881)))
        );
        contractToTest.setMap5Value(index1, index2, inputValue);
        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(contractAddress);

        assertEq(lastWrittenSlots.length, 1);
        bytes32 retrievedValue = vm.load(contractAddress, lastWrittenSlots[0]);
        assertEq(retrievedValue, bytes32(uint256(uint160(inputValue.value))));

        console.log("map5[10][address(18)].value = address(8881)");
        console.log(
            "@slot:%s => %s (%s)",
            Strings.toHexString(uint256(lastWrittenSlots[0])),
            Strings.toHexString(uint256(retrievedValue)),
            abi.decode(bytes.concat(retrievedValue), (uint256)) //uint256(retrievedValue)
        );

        // retrieve with stdtore see: https://book.getfoundry.sh/reference/forge-std/std-storage
        uint256 stdstoreSlot = stdstore
            .target(contractAddress)
            .sig("getMap5(uint256,address)")
            .with_key(index1)
            .with_key(index2)
            .find();

        uint256 shift = 1;
        assertEq(lastWrittenSlots[0], bytes32(stdstoreSlot + shift));

        // calculate slot value
        bytes32 slot = bytes32(
            uint256(keccak256(abi.encode(index2, keccak256(abi.encode(index1, rootSlot))))) + shift
        );
        assertEq(lastWrittenSlots[0], slot);
    }
}
