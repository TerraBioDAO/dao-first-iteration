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

abstract contract BaseDaoTest is Test {
    DaoCore public dao;
    TBIOToken public tbio;
    Bank public bank;
    address public ADMIN;
    address public constant ZERO = address(0);
    uint256 public constant TOKEN = 10**18;
    uint32 public constant DAY = 86400;

    function setUp() public virtual {
        _deployDao(address(501));
        _deployTBIO();
        bank = new Bank(address(dao), address(tbio));
        _branch(Slot.BANK, address(bank));
    }

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
