// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface ISlotEntry {
    function isExtension() external view returns (bool);

    function slotId() external view returns (bytes4);
}
