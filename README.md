# Shipping Invoice Funding Platform

A blockchain-based platform that enables exporters to get short-term loans against shipping invoices, with investors funding curated pools of invoices for returns.

## Overview

This platform connects exporters, investors, and admins through smart contracts to facilitate secure and transparent shipping invoice financing. The system uses NFTs to represent both individual invoices and pools of curated invoices.

### Key Features

- **Invoice NFTs**: Individual shipping invoices represented as ERC-721 tokens
- **Pool NFTs**: Curated bundles of invoices for investment
- **70% Funding Threshold**: Exporters can withdraw when invoices reach 70% funding
- **Profit Sharing**: 4% yield for investors + 1% platform fee
- **Role-based Access**: Admin, Exporter, and Investor roles

## Prerequisites

- **Node.js**: v18.0.0 or higher
- **Git**: Latest version
- **Foundry**: Ethereum development toolkit

## Setup

### 1. Install Foundry

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Clone and Setup Repository

```bash
# Clone the repository
git clone https://github.com/SEATrax/smart-contract.git
cd smart-contract

# Initialize dependencies (IMPORTANT!)
git submodule update --init --recursive

# Alternative: use forge install
forge install

# Verify setup
forge build
```

### 3. Environment Configuration

Create a `.env` file in the root directory:

```env
# Lisk Sepolia Testnet Configuration
LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
LISK_SEPOLIA_CHAIN_ID=4202
LISK_SEPOLIA_EXPLORER=https://sepolia-blockscout.lisk.com

# Deployment
PRIVATE_KEY=your_private_key_here
ADMIN_ADDRESS=your_admin_address
```

## Development Commands

### Build

```bash
forge build
```

### Test

```bash
forge test

# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test testInvoiceCreation
```

### Format

```bash
forge fmt
```

### Gas Analysis

```bash
forge snapshot
```

### Local Development

```bash
# Start local blockchain
anvil

# Deploy locally (in another terminal)
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
```

## Deployment

Deploy to Lisk Sepolia Testnet:

```bash
# Basic deployment
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $LISK_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

# With contract verification
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $LISK_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url $LISK_SEPOLIA_EXPLORER/api
```

### Network Details
- **Network Name**: Lisk Sepolia Testnet
- **Chain ID**: 4202
- **RPC URL**: https://rpc.sepolia-api.lisk.com
- **Currency**: ETH
- **Explorer**: https://sepolia-blockscout.lisk.com

## Project Structure

```
├── src/                           # Smart contracts
│   ├── AccessControl.sol         # Role-based access control
│   ├── InvoiceNFT.sol           # Individual invoice NFTs
│   ├── PoolNFT.sol              # Pool of invoices NFTs
│   ├── PoolFundingManager.sol   # Investment and funding logic
│   └── PaymentOracle.sol        # Payment confirmation system
├── test/                         # Test files
├── script/                       # Deployment scripts
│   └── Deploy.s.sol
├── .github/                      # Project documentation
│   ├── implementation-checklist.md
│   └── copilot-instruction-overview-project.md
└── foundry.toml                 # Foundry configuration
```

## Troubleshooting

### Common Issues

**Build fails with missing dependencies:**
```bash
git submodule update --init --recursive
forge install
```

**Test failures:**
```bash
forge clean
forge build
forge test
```

**Deployment fails:**
- Check your `.env` file configuration
- Ensure you have sufficient ETH on Lisk Sepolia
- Verify network connectivity

## Contributing

1. Follow the implementation phases in `.github/implementation-checklist.md`
2. Ensure all tests pass: `forge test`
3. Check code formatting: `forge fmt`
4. Verify contracts build: `forge build`

## Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Lisk Sepolia Faucet](https://sepolia-faucet.lisk.com/)
- [Implementation Progress](.github/implementation-checklist.md)

## Help

```bash
forge --help
anvil --help
cast --help
```
