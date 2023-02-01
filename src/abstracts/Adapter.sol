// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Counters } from "openzeppelin-contracts/utils/Counters.sol";

import { SlotEntry } from "./SlotEntry.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";
import { Constants } from "../helpers/Constants.sol";

/**
 * @title Abstract contract to implement restriction access of Adatpers
 * @dev Only implement modifiers and internal functions, not states is implemented
 */
abstract contract Adapter is SlotEntry, Constants {
    /// @dev Allow only DaoCore
    modifier onlyCore() {
        require(msg.sender == _core, "Adapter: not the core");
        _;
    }

    /**
     * @dev Allow only a specific Extensions
     * @param slot slotID of the extensions
     */
    modifier onlyExtension(bytes4 slot) {
        IDaoCore core = IDaoCore(_core);
        require(
            core.isSlotExtension(slot) && core.getSlotContractAddr(slot) == msg.sender,
            "Adapter: wrong extension"
        );
        _;
    }

    /// @dev Allow only Members
    modifier onlyMember() {
        require(IDaoCore(_core).hasRole(msg.sender, ROLE_MEMBER), "Adapter: not a member");
        _;
    }

    /// @dev Allow only Proposer (not implemented)
    modifier onlyProposer() {
        require(IDaoCore(_core).hasRole(msg.sender, ROLE_PROPOSER), "Adapter: not a proposer");
        _;
    }

    /// @dev Allow only Admin
    modifier onlyAdmin() {
        require(IDaoCore(_core).hasRole(msg.sender, ROLE_ADMIN), "Adapter: not an admin");
        _;
    }

    /**
     * @param core address of DaoCore
     * @param slot slotID of the adapter
     */
    constructor(address core, bytes4 slot) SlotEntry(core, slot, false) {}

    receive() external payable {
        revert("Adapter: cannot receive funds");
    }

    /**
     * @dev Internal getter to read slotID
     * @param slot slotID to read
     * @return Actual contract address associated with `slot`, return
     * address(0) if there is no contract address
     */
    function _slotAddress(bytes4 slot) internal view returns (address) {
        return IDaoCore(_core).getSlotContractAddr(slot);
    }
}
