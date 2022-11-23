// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "openzeppelin-contracts/utils/Strings.sol";
import "forge-std/StdJson.sol";

import "./BaseDao.s.sol";

abstract contract DaoRecorder is BaseDao {
    using Strings for uint256;
    using stdJson for string;

    struct InitialSetup {
        address deployer;
        address[] admins;
        address[] membres;
    }

    struct Contracts {
        address agora;
        address bank;
        address daoCore;
        address financing;
        address managing;
        address onboarding;
        address tbio;
        address voting;
    }

    struct Network {
        Contracts deployed;
        InitialSetup initialSetup;
    }

    /// @notice states
    string internal path;
    string internal contracts = "contracts";
    string internal initialSetup = "initialSetup";
    string internal network = "network";

    function initPath() internal returns (string memory networkAlias) {
        networkAlias = _findNetworkAlias();
        path = string.concat("script/utils/", networkAlias, ".json");
    }

    // function loadNetworkState() internal {
    //     Contracts memory parsedContracts = abi.decode(readRecordKey(".contracts"),(Contracts))
    //     dao=
    // }

    /**
     * @notice Returns bytes memory to read with `abi.decode(rawJson,(types/Struct))`
     *
     * NOTE use Struct only if all types are the same
     */
    function readRecordKey(string memory key) internal returns (bytes memory) {
        string memory file = vm.readFile(path);
        return file.parseRaw(key);
    }

    function writeRecord(
        string memory networkAlias,
        address deployer,
        address[] memory admins,
        address[] memory members
    ) internal {
        vm.writeFile(path, "");

        // write current contract address
        string memory index = "contractAddr";
        string memory serializedAt;

        serializedAt = index.serialize("Agora", address(agora));
        serializedAt = index.serialize("Bank", address(bank));
        serializedAt = index.serialize("DaoCore", address(dao));
        serializedAt = index.serialize("Financing", address(financing));
        serializedAt = index.serialize("Managing", address(managing));
        serializedAt = index.serialize("Onboarding", address(onboarding));
        serializedAt = index.serialize("Voting", address(voting));
        serializedAt = index.serialize("TBIO", address(tbio));

        contracts = serializedAt;

        // write initial setup
        index = "setup";
        delete serializedAt;
        serializedAt = index.serialize("deployer", deployer);
        serializedAt = index.serialize("admins", admins);
        serializedAt = index.serialize("members", members);

        initialSetup = serializedAt;

        index = ".";
        delete serializedAt;
        serializedAt = index.serialize("initialSetup", initialSetup);
        serializedAt = index.serialize("contracts", contracts);

        network = network.serialize(networkAlias, serializedAt);

        network.write(path);
    }

    function _findNetworkAlias() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 5) {
            return "goerli";
        } else {
            // 31337
            return "anvil";
        }
    }
}
