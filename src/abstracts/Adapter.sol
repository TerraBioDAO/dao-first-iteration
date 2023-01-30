// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Counters } from "openzeppelin-contracts/utils/Counters.sol";

import { SlotEntry } from "./SlotEntry.sol";
import { IDaoCore } from "../interfaces/IDaoCore.sol";
import { Constants } from "../helpers/Constants.sol";

/**
 * @notice abstract contract for Adapters, add guard modifier
 * to restrict access for only DAO members or contracts.
 *
 * NOTE This contract has no state, there is no need to reset it
 * when the contract is desactived
 */
abstract contract Adapter is SlotEntry, Constants {
    /* //////////////////////////
            MODIFIER
    ////////////////////////// */
    modifier onlyCore() {
        require(msg.sender == _core, "Adapter: not the core");
        _;
    }

    modifier onlyExtension(bytes4 slot) {
        IDaoCore core = IDaoCore(_core);
        require(
            core.isSlotExtension(slot) && core.getSlotContractAddr(slot) == msg.sender,
            "Adapter: wrong extension"
        );
        _;
    }

    /// NOTE consider using `hasRole(bytes4)` for future role in the DAO => AccessControl.sol
    modifier onlyMember() {
        require(IDaoCore(_core).hasRole(msg.sender, ROLE_MEMBER), "Adapter: not a member");
        _;
    }

    modifier onlyProposer() {
        require(IDaoCore(_core).hasRole(msg.sender, ROLE_PROPOSER), "Adapter: not a proposer");
        _;
    }

    modifier onlyAdmin() {
        require(IDaoCore(_core).hasRole(msg.sender, ROLE_ADMIN), "Adapter: not an admin");
        _;
    }

    constructor(address core, bytes4 slot) SlotEntry(core, slot, false) {}

    receive() external payable {
        revert("Adapter: cannot receive funds");
    }

    /**
     * @notice internal getter
     * @return actual contract address associated with `slot`, return
     * address(0) if there is no contract address
     */
    function _slotAddress(bytes4 slot) internal view returns (address) {
        return IDaoCore(_core).getSlotContractAddr(slot);
    }
}
