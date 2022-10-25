// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "src/helpers/Slot.sol";
import "src/core/DaoCore.sol";
import "test/base/BaseTest.sol";

contract FakeEntry {
    bytes4 public slotId;
    bool public isExtension;

    constructor(bytes4 slot, bool isExt) {
        slotId = slot;
        isExtension = isExt;
    }
}

contract TBIOToken is ERC20 {
    constructor() ERC20("TerraBioToken", "TBIO") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

/// @notice use `e18` to add a decimal instead of `TOKEN = 10**18`

abstract contract BaseDaoTest is BaseTest {
    DaoCore public dao;
    TBIOToken public tbio;

    address public ADMIN;
    address public constant ZERO = address(0);
    uint32 public constant DAY = 86400;

    mapping(bytes4 => bool) internal _slotUsed;

    function _slotValid(bytes4 slot) internal view returns (bool) {
        return _slotUsed[slot];
    }

    function _deployDao(address admin) internal {
        ADMIN = admin;
        dao = new DaoCore(ADMIN);
        _slotUsed[Slot.CORE] = true;
        _slotUsed[Slot.EMPTY] = true;
    }

    function _deployTBIO() internal {
        tbio = new TBIOToken();
    }

    function _mintTBIO(address account, uint256 amount) internal {
        require(address(tbio) != address(0), "BaseDaoTest: TBIO not deployed");
        tbio.mint(account, amount);
    }

    function _branch(bytes4 slot, address contractAddr) internal {
        vm.prank(ADMIN);
        dao.changeSlotEntry(slot, contractAddr);
        _slotUsed[slot] = true;
    }

    function _branchMock(bytes4 slot, bool isExt) internal returns (address mockEntry) {
        mockEntry = _newEntry(slot, isExt);
        vm.prank(ADMIN);
        dao.changeSlotEntry(slot, mockEntry);
        _slotUsed[slot] = true;
    }

    function _newEntry(bytes4 slot, bool isExt) internal returns (address entry) {
        entry = address(new FakeEntry(slot, isExt));
    }
}
