// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin-contracts/utils/Counters.sol";

import "./SlotEntry.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IDaoCore.sol";
import "../helpers/Constants.sol";

abstract contract Adapter is SlotEntry, IAdapter, Constants {
    constructor(address core, bytes4 slot) SlotEntry(core, slot, false) {}

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

    function eraseAdapter() external override onlyCore {
        selfdestruct(payable(_core));
    }
}
