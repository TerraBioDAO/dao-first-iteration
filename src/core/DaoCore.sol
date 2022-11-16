// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../abstracts/Extension.sol";
import "../interfaces/IDaoCore.sol";
import "../helpers/Constants.sol";

contract DaoCore is Extension, IDaoCore, Constants {
    /// @notice track all members of the DAO with their roles
    mapping(address => mapping(bytes4 => bool)) public members;

    /// @notice counter of existing members
    uint256 public override membersCount;

    /// @notice list of existing roles in the DAO
    bytes4[] private _roles;

    /// @notice track of Extensions and Adapters
    mapping(bytes4 => Entry) public entries;

    /**
     * @notice `admin` become grant the role of MANAGING and ONBOARDING to add
     * new member in the DAO and new Entries
     */
    constructor(address admin) Extension(address(this), Slot.CORE) {
        _addAdmin(admin);
        _addSlotEntry(Slot.MANAGING, admin, false);
        _addSlotEntry(Slot.ONBOARDING, admin, false);

        // push roles
        _roles.push(ROLE_MEMBER);
        _roles.push(ROLE_ADMIN);
        _roles.push(ROLE_PROPOSER);
    }

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
    function changeMemberStatus(
        address account,
        bytes4 role,
        bool value
    ) external onlyAdapter(Slot.ONBOARDING) {
        require(account != address(0), "Core: zero address used");
        if (role == ROLE_MEMBER && !value) {
            _revokeMember(account);
        } else {
            _changeMemberStatus(account, role, value);
        }
        emit MemberStatusChanged(account, role, value);
    }

    function addNewAdmin(address account) external onlyAdapter(Slot.ONBOARDING) {
        require(account != address(0), "Core: zero address used");
        _addAdmin(account);
        emit MemberStatusChanged(account, ROLE_ADMIN, true);
    }

    function changeSlotEntry(bytes4 slot, address contractAddr)
        external
        onlyAdapter(Slot.MANAGING)
    {
        require(slot != Slot.EMPTY, "Core: empty slot");
        Entry memory e = entries[slot];

        if (contractAddr == address(0)) {
            _removeSlotEntry(slot);
        } else {
            // low level call "try/catch" => https://github.com/dragonfly-xyz/useful-solidity-patterns/tree/main/patterns/error-handling#low-level-calls
            (, bytes memory slotIdData) = address(contractAddr).staticcall(
                // Encode the call data (function on someContract to call + arguments)
                abi.encodeCall(ISlotEntry.slotId, ())
            );
            if (slotIdData.length != 32) {
                revert("Core: inexistant slotId() impl");
            }
            require(bytes4(slotIdData) == slot, "Core: slot & address not match");

            if (e.slot == Slot.EMPTY) {
                e.isExtension = ISlotEntry(contractAddr).isExtension();
                _addSlotEntry(slot, contractAddr, e.isExtension);
            } else {
                // replace => ext is ext!
                bool isExt = ISlotEntry(contractAddr).isExtension();
                require(e.isExtension == isExt, "Core: wrong entry setup");
                e.isExtension = isExt; // for event
                _addSlotEntry(slot, contractAddr, isExt);
            }
        }

        emit SlotEntryChanged(slot, e.isExtension, e.contractAddr, contractAddr);
    }

    /* //////////////////////////
                GETTERS
    ////////////////////////// */
    function hasRole(address account, bytes4 role) external view returns (bool) {
        return members[account][role];
    }

    function getRolesList() external view returns (bytes4[] memory) {
        return _roles;
    }

    function isSlotActive(bytes4 slot) external view returns (bool) {
        return entries[slot].slot != Slot.EMPTY;
    }

    function isSlotExtension(bytes4 slot) external view returns (bool) {
        return entries[slot].isExtension;
    }

    function getSlotContractAddr(bytes4 slot) external view returns (address) {
        return entries[slot].contractAddr;
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
    function _addAdmin(address account) internal {
        if (!members[account][ROLE_MEMBER]) {
            unchecked {
                ++membersCount;
            }
            members[account][ROLE_MEMBER] = true;
        }
        require(!members[account][ROLE_ADMIN], "Core: already an admin");
        members[account][ROLE_ADMIN] = true;
    }

    function _revokeMember(address account) internal {
        bytes4[] memory rolesList = _roles;

        for (uint256 i; i < rolesList.length; ) {
            delete members[account][rolesList[i]];
            unchecked {
                ++i;
            }
        }
        unchecked {
            --membersCount;
        }
    }

    function _changeMemberStatus(
        address account,
        bytes4 role,
        bool value
    ) internal {
        require(members[account][role] != value, "Core: role not changing");
        if (role == ROLE_MEMBER && value) {
            unchecked {
                ++membersCount;
            }
        }
        members[account][role] = value;
    }

    function _addSlotEntry(
        bytes4 slot,
        address newContractAddr,
        bool isExt
    ) internal {
        entries[slot] = Entry(slot, isExt, newContractAddr);
    }

    function _removeSlotEntry(bytes4 slot) internal {
        delete entries[slot];
    }
}
