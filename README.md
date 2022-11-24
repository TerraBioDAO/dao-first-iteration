# TerraBio DAO

![](https://img.shields.io/badge/Foundry-0.2.0__b28119b-green)

_Explication du repo_

# After git clone

Make sure you have install [Rust](https://www.rust-lang.org/fr/learn/get-started) & [Foundry](https://book.getfoundry.sh/getting-started/installation)

```
forge install
forge update
```

Then add `.env` file following `.env.exemple`:

```
INFURA_API_KEY=12345
ETHERSCAN_KEY=12345

DEPLOYER_anvil=0x...
DEPLOYER_goerli=0x...
```

# Unit testing

_Static analysis and workflows are described in `test/`_

Run tests:

```
forge test
```

Add verbosity, `-vv` logs & reverts, `-vvvv` detailled traces:

```
forge test -vv
```

Match contract:

```
forge test --match-contract Agora
```

Match test:

```
forge test --match-test testSubmitProposal
```

Match allow specific filtering, running each tests containing "Slot" in `DaoCore_test` contract:

```
forge test --match-contract DaoCore --match-test Slot
```

# Deploy and run scripts

_System deployment is descirbed in `script/`_

## Run script locally

```
forge script logs
```

`script/logs.s.sol` is used to log any variables using [`forge-std/Test.sol`](https://book.getfoundry.sh/reference/ds-test#logging). Can be useful to ABI-encode complex arguments.

Simulate system deployment script:

```
forge script deployer
```

The script run on local, it's useful to test the script.

_This script deploy all contracts of the DAO at once, consider create another script to run more precise operation of deployment or contract interaction_

## Run scripts on local blockchain

Foundry provide a local blockhain like Ganache from Truffle, named [Anvil](https://book.getfoundry.sh/reference/anvil/)

Start local blockchain:

```
anvil
```

Run the script with the RPC URL:

```
forge script deployer --rpc-url anvil
```

Running on `anvil` (or any RPC URL) give :

- a gas estimation of transactions in the script
- the list of transactions created with the script in `broadcast/scriptName/chainId/run-latest.json`

**But do not send transactions to the blockchain**

## Running script on forked network

Tests and scripts can be runned on a forked network:

```
forge script deployer --fork-url goerli
```

Like running with an RPC URL, the script will estimate transaction gas cost and save transactions list.

Forked network can be manipulated with many parameters, see the [documentation](https://book.getfoundry.sh/tutorials/forking-mainnet-with-cast-anvil) or run `forge script --help` and check **EXECUTOR ENVIRONMENT CONFIG**

Run on forked network at a past block number:

```
forge script deployer --fork-url goerli --fork-block-number 7999999
```

Can be useful to run again transactions and retrieve contracts.

## Send transaction to the network

To send transaction on blockchain through RPC URL, you have to pass `--broadcast` argument.

⚠️ **Carefully check and test your script before run a script with `--broadcast` on a non-local network**

```
forge script deployer --rpc-url goerli --broadcast
```

Gas price and gas limit should set properly in the config or in the command.

⚠️⚠️ **Running your script with `--fork-url` will also send transaction to the network**

# Interact with contracts with CLI

Foundry provide a tool, [Cast](https://book.getfoundry.sh/cast/), to interact with deployed contract on anvil or any **forked** network (you cannot send real transaction with Cast).

Run a blockchain locally:

```
anvil
```

Deploy your contracts:

```
forge script deployer --rpc-url anvil --broadcast
```

Then you can use **Cast** to call smart contract:

```
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "membersCount()"
```

## Environment variables

To facilitate use of cast you can run:

```
forge script printEnv --chain anvil
```

This will create a file `.anvil` (network name) with contracts address just deployed. Address are stored in `script/utils/anvil.json`

Source your environment:

```
source .anvil
```

Then you can cast call more easily:

```
cast call $DAO "memberCount()"
```

## Interact on any network

To interact with any network you can create a fork with `anvil` and cast transaction on it:

```
anvil --fork-url https://goerli.infura.io/v3/$INFURA_API_KEY
```

_(Make sure you called `source .env` to load api key)_

⚠️ **Always run your script with `--rpc-url anvil` otherwise it send transaction to the network:**

```
forge script deployer --rpc-url anvil --broadcast
```

Then you take variable from environment:

```
forge script printEnv --chain goerli
source .goerli
```

_The script do not differentiate the forked network and the real one. => Need improvment_

```
cast call $DAO "membersCount()"
```

💡 To get back address from a deployment, if you was the deployer (knowing the private key) you can simulate again the deployment:

```
forge script deployer --fork-url goerli --fork-block-number 7999948
```

Then source contracts:

```
forge script printEnv --rpc-url goerli
source .goerli
```

# Verify contracts on explorer

To verify contracts your need first API KEY, depending on where you want to verify the contract, set in the `.env`

## When deploying the contract

You can pass the `--verify $ETHERSCAN_KEY` argument at contract deployment, using `forge create` or a script.

❔ This method need to be tried. Some delay can occur with the explorer and make fail the process.

## Verify a deployed contract

You need to get the **constructor argument** (if there is at least one) to submit a verification. You can construct it with Cast:

```
cast abi-encode "constructor(address)" $ADDRESS
```

```
cast abi-encode "constructor(address,address)" $ADDRESS1 $ADDRESS2
```

Assume you have sourced your environment with contract (and deployer, admins, ...) address:

```
forge verify-contract $AGORA Agora --chain goerli --constructor-args 0000000000000000000000003e8d55ec9aae810460d5e96050247 $ETHERSCAN_KEY --watch
```

The constructor argument is a `bytes` not prefixed with `0x`.  
`$AGORA` is the address of the contract  
`--watch` wait until the contract is verified
