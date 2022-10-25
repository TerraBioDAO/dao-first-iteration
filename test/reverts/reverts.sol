// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "src/interfaces/IDaoCore.sol";
import "src/interfaces/IAgora.sol";
import "src/interfaces/IBank.sol";

contract Revert {
    fallback() external {
        // every call on this contract fall there
        revert();
    }
}

abstract contract ERC20_reverts is Revert, IERC20 {}

abstract contract Core_reverts is Revert, IDaoCore {}

abstract contract Agora_reverts is Revert, IAgora {}

abstract contract Bank_reverts is Revert, IBank {}
