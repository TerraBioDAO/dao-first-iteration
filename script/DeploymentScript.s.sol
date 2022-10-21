// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "forge-std/Script.sol";
import "../src/core/DaoCore.sol";
import "../src/extensions/Bank.sol";
import "../src/extensions/Agora.sol";
import "../src/adapters/Voting.sol";
import "../src/adapters/Financing.sol";
import "../src/adapters/Managing.sol";
import "../src/adapters/Onboarding.sol";

contract TBIOToken is ERC20 {
    constructor() ERC20("TerraBioToken", "TBIO") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

contract DeploymentScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("ANVIL_PRIVATE_KEY"));

        // Token deployment => TODO adresse à récupérer si déploiement déjà effectué
        TBIOToken tbio = new TBIOToken();

        // DAO Core deployment
        DaoCore daoCore = new DaoCore(address(vm.envAddress("ANVIL_ADMIN_PUBLIC")));

        // Extensions deployment
        new Bank(address(daoCore), address(tbio));
        new Agora(address(daoCore));

        // Adapters deployment
        new Voting(address(daoCore));
        new Financing(address(daoCore));
        Managing managing = new Managing(address(daoCore));
        Onboarding onboarding = new Onboarding(address(daoCore));

        vm.stopBroadcast();

        // associate slot to SmartContracts
        vm.startBroadcast(vm.envUint("ANVIL_ADMIN_PRIVATE"));
        daoCore.changeSlotEntry(Slot.ONBOARDING, address(onboarding));
        daoCore.changeSlotEntry(Slot.MANAGING, address(managing));
        vm.stopBroadcast();
    }
}
