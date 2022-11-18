// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin-contracts/utils/Counters.sol";

import "./SlotEntry.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IDaoCore.sol";
import "../helpers/Constants.sol";

/**
 * @notice abstract contract for Adapters, add guard modifier
 * to restrict access for only DAO members or contracts
 */
abstract contract Adapter is SlotEntry, IAdapter, Constants {
    constructor(address core, bytes4 slot) SlotEntry(core, slot, false) {}

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

    /* //////////////////////////
            FUNCTIONS
    ////////////////////////// */
    /**
     * @notice delete storage and destruct the contract,
     * calls can still happen and ethers sended there are lost
     * for ever.
     *
     * @dev only callable when the contract is unplugged from DaoCore
     *
     * NOTE this operation is quite useless as the contract as not state
     */
    function eraseAdapter() public virtual override onlyExtension(Slot.AGORA) {
        require(
            IDaoCore(_core).getSlotContractAddr(slotId) != address(this),
            "Adapter: unplug from DaoCore"
        );
        selfdestruct(payable(_core));
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
