// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "src/helpers/Slot.sol";
import "src/helpers/Constants.sol";
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

abstract contract BaseDaoTest is BaseTest, Constants {
    DaoCore public dao;
    TBIOToken public tbio;

    address internal ADMIN;
    address internal DAO;
    address internal TBIO;
    address internal constant ZERO = address(0);
    address[] internal USERS;
    bytes4 VOTE_STANDARD_RAW_VALUE = hex"54fd88eb";

    mapping(bytes4 => bool) internal _activeSlot;

    function _isSlotActive(bytes4 slot) internal view returns (bool) {
        return _activeSlot[slot];
    }

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
            dao.changeMemberStatus(USERS[i], ROLE_MEMBER, true);
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
        _activeSlot[slot] = true;
    }

    function _branchMock(bytes4 slot, bool isExt) internal returns (address mockEntry) {
        mockEntry = _newEntry(slot, isExt);
        vm.prank(ADMIN);
        dao.changeSlotEntry(slot, mockEntry);
        _activeSlot[slot] = true;
    }

    function _newEntry(bytes4 slot, bool isExt) internal returns (address entry) {
        entry = address(new FakeEntry(slot, isExt));
    }
}
