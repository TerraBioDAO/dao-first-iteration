// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "src/helpers/Slot.sol";
import "src/core/DaoCore.sol";

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

// non implémenté mais peut être utile
contract MockDaoCore {
    function getSlotContractAddr(bytes4 slot) external pure returns (address) {
        return slot == Slot.FINANCING ? address(uint160(uint32(Slot.FINANCING))) : address(0);
    }
}

abstract contract BaseDaoTest is Test {
    DaoCore public dao;
    TBIOToken public tbio;
    address public ADMIN;
    address public constant ZERO = address(0);
    uint256 public constant TOKEN = 10**18;
    uint32 public constant DAY = 86400;

    function _deployDao(address admin) internal {
        ADMIN = admin;
        dao = new DaoCore(ADMIN, ADMIN);
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
    }

    function _branchMock(bytes4 slot, bool isExt) internal returns (address mockEntry) {
        mockEntry = _newEntry(slot, isExt);
        vm.prank(ADMIN);
        dao.changeSlotEntry(slot, mockEntry);
    }

    function _newEntry(bytes4 slot, bool isExt) internal returns (address entry) {
        entry = address(new FakeEntry(slot, isExt));
    }
}
