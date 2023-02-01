// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import { DaoCore } from "src/DaoCore.sol";
import { Agora } from "src/extensions/Agora.sol";
import { Bank } from "src/extensions/Bank.sol";
import { Financing } from "src/adapters/Financing.sol";
import { Onboarding } from "src/adapters/Onboarding.sol";
import { Managing } from "src/adapters/Managing.sol";
import { Voting } from "src/adapters/Voting.sol";
import { Slot } from "src/helpers/Slot.sol";

import { MockERC20 } from "test/MockERC20.sol";

abstract contract BaseDao is Script {
    // internal contracts
    IERC20 internal tbio;
    DaoCore internal dao;
    Bank internal bank;
    Agora internal agora;
    Managing internal managing;
    Onboarding internal onboarding;
    Voting internal voting;
    Financing internal financing;

    // internal characters
    address internal DEPLOYER;
    address[] internal ADMINS;
    address[] internal MEMBERS;

    /* //////////////////////////
         DEPLOYMENT FUNCTIONS
    ////////////////////////// */

    // Token
    function _0_deployTBIO() internal {
        tbio = new MockERC20();
    }

    // DaoCore
    function _1_deployDaoCore(address deployer) internal {
        dao = new DaoCore(deployer);
    }

    // Extensions
    function _2a_deployAgora() internal {
        agora = new Agora(address(dao));
    }

    function _2b_deployBank() internal {
        bank = new Bank(address(dao), address(tbio));
    }

    // Adapters
    function _3a_deployManaging(bool branchIt) internal {
        managing = new Managing(address(dao));
        if (branchIt) {
            dao.changeSlotEntry(Slot.MANAGING, address(managing));
        }
    }

    function _3b_deployOnboarding(bool branchIt) internal {
        onboarding = new Onboarding(address(dao));
        if (branchIt) {
            dao.changeSlotEntry(Slot.ONBOARDING, address(onboarding));
        }
    }

    function _3c_deployVoting(bool branchIt) internal {
        voting = new Voting(address(dao));
        if (branchIt) {
            dao.changeSlotEntry(Slot.VOTING, address(voting));
        }
    }

    function _3d_deployFinancing(bool branchIt) internal {
        financing = new Financing(address(dao));
        if (branchIt) {
            dao.changeSlotEntry(Slot.FINANCING, address(financing));
        }
    }

    // Post deployment
    function _4a_addAdmins(address[] memory admins) internal {
        //
    }

    function _4b_addMembers(address[] memory members) internal {
        //
    }

    function _4c_branchAdpater(bytes4 slot, address contractAddr) internal {
        dao.changeSlotEntry(slot, contractAddr);
    }
}
