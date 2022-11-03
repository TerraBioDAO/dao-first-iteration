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
    DaoCore internal dao;
    TBIOToken internal tbio;

    address internal ADMIN;
    address internal DAO;
    address internal TBIO;
    address internal constant ZERO = address(0);
    uint32 internal constant DAY = 86400;
    address[] internal USERS;

    function _deployDao(address admin) internal {
        ADMIN = admin;
        dao = new DaoCore(ADMIN);
        DAO = address(dao);
    }

    function _deployTBIO() internal {
        tbio = new TBIOToken();
        TBIO = address(tbio);
    }

    function _newUsersSet(uint160 offset, uint256 length) internal {
        address[] memory list = new address[](length);

        for (uint160 i; i < length; i++) {
            list[i] = address(i + offset + 1);
        }
        USERS = list;
    }

    function _setAsMembers() internal {
        vm.startPrank(dao.getSlotContractAddr(Slot.ONBOARDING));
        for (uint256 i; i < USERS.length; i++) {
            dao.changeMemberStatus(USERS[i], Slot.USER_EXISTS, true);
        }
        vm.stopPrank();
    }

    function _mintTBIOForAll(uint256 amount) internal {
        for (uint256 i; i < USERS.length; i++) {
            tbio.mint(USERS[i], amount);
        }
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
