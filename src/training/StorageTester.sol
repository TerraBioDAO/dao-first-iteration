pragma solidity 0.8.17;

contract StorageTester {
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

    constructor() {}
}
