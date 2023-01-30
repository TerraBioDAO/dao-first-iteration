// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IEntry {
    function lastVersion() external view returns (address);

    function isExtension() external view returns (bool);
}
