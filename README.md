## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Environment Setup

Create a `.env` file in the root directory:

```env
# Lisk Sepolia Testnet Configuration
LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
LISK_SEPOLIA_CHAIN_ID=4202
LISK_SEPOLIA_EXPLORER=https://sepolia-blockscout.lisk.com

# Deployment
PRIVATE_KEY=your_private_key_here
ADMIN_ADDRESS=your_admin_address
INVESTMENT_MANAGER_ADDRESS=your_investment_manager_address
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Deploy to Lisk Sepolia Testnet:

```shell
$ forge script script/Deploy.s.sol:DeployScript --rpc-url $LISK_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast

# With contract verification on Blockscout
$ forge script script/Deploy.s.sol:DeployScript --rpc-url $LISK_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $LISK_SEPOLIA_EXPLORER/api
```

**Network Details:**
- Network Name: Lisk Sepolia Testnet
- Chain ID: 4202
- RPC URL: https://rpc.sepolia-api.lisk.com
- Currency Symbol: ETH
- Block Explorer: https://sepolia-blockscout.lisk.com

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
