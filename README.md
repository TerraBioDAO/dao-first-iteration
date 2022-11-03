# TerraBio DAO


## Workflows

Le *workflows* permet de voir le coverage des tests, les tests permettent d'écrire le *workflows*.

`Contrat.fonction(paramêtres)`

1. **Personnage** fait `Action`
    - changements d'état de la DAO (Core ou extensions)
    - ...
    - ...

### Entrée dans la DAO

1. **User** appelle `Onboarding.joinDao()`
    - User obtient le status de **Membre** (Core)
    - Le nombre total de membres augmente

## Déploiement de la DAO

### Principe général

1. **Deployer** déploie `DaoCore(adminAddr)`
2. **Deployer ou Admin** deploie les `extensions & adapters`
3. **Admin** appelle `DaoCore.changeSlotEntry(slot, contractAddr)`
    - association d'un contrat à un slot extensions ou adaptateurs (Core)
4. **Admin** appelle `DaoCore.changeSlotEntry(Slot.MANAGING, managingAddr)`
    - redonne la gestion des slots au contrat `Managing`
5. La DAO peut être utilisée

Ajout de membres durant le déploiement ?  
Possibilité de *batcher* l'ajout de slot et de membres ?

### Mise en pratique avec forge script

On se base sur `forge script` de  [Foundry Book](https://book.getfoundry.sh/tutorials/solidity-scripting.html):

> Solidity scripts are like the scripts you write when working with tools like Hardhat; what makes Solidity scripting different is that they are written in Solidity instead of JavaScript, and they are run on the fast Foundry EVM backend, which provides dry-run capabilities.


#### Deployer localement

Next start Anvil, the local Foundry's testnet:

```sh
anvil
```

Once started, Anvil will give you a local RPC endpoint as well as a handful of Private Keys and Accounts that you can use.

We can now use the local RPC along with one of the private keys to deploy locally

Renseigner au préalable les adresses des comptes souhaités dans votre fichier .env :

```sh
ANVIL_PRIVATE_KEY=
ANVIL_ADMIN_PUBLIC=
ANVIL_ADMIN_PRIVATE=
```

Lancer le script de déploiement :

```sh
forge script script/DeploymentScript.s.sol:DeploymentScript --fork-url http://localhost:8545  --broadcast
```

#### Using cast to perform Ethereum RPC calls

Once the contract has been deployed locally, Anvil will log out the contract address.

Next, set the contract address as an environment variable:

```sh
export DAO_CORE_ADDRESS=<contract-address>
```

We can then perform read operations with `cast call`:

```sh
cast call $DAO_CORE_ADDRESS "membersCount()(uint256)"
```

#### Deploying to a network

Now that we've deployed and tested locally, we can deploy to a network.

To do so, run the following script:

```sh
forge script script/DeploymentScript.s.sol:DeploymentScript  --rpc-url $RPC_URL \
 --private-key $PRIVATE_KEY --broadcast
```

Once the contract has been deployed to the network, we can use cast send to test sending transactions to it:

```sh
cast send $DAO_CORE_ADDRESS "addNewAdmin('Ox')" --rpc-url $RPC_URL \
--private-key $PRIVATE_KEY 
```

We can then perform read operations with cast call:

```sh
cast call $DAO_CORE_ADDRESS "membersCount()(uint256)"
```

#### Cast Options

```sh
cast --help
```

#### Logs

Les traces avec les transactions et les adresses des contrats déployés sont disponibles dans le répertoire `broadcast` 

# Static analysis

## Slither

[Docs](https://github.com/crytic/slither)

```
apt install python3-pip
pip3 install slither-analyzer
pip3 install solc-select
solc-select install 0.8.17
solc-select use 0.8.17
```

**Analyze:**
```
slither src/core/DaoCore.sol
```