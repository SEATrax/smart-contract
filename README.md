# Export-Import Funding Platform

A decentralized platform for international trade financing built with Solidity smart contracts and Foundry framework.

## Overview

This platform connects importers, exporters, and investors through blockchain technology to facilitate secure and transparent export-import financing. The system uses NFTs to represent trade contracts, pools investments across multiple contracts, and manages escrow payments with automated releases.

### Key Features

- **NFT-based Trade Contracts**: ERC-721 tokens representing approved import-export agreements
- **Investment Pools**: Bundle multiple contracts for risk distribution
- **Automated Escrow**: Secure payment handling with oracle-verified releases
- **Role-based Access Control**: Admin, Importer, Exporter, and Investor roles
- **Proportional Returns**: Investors receive returns based on their pool contributions

## Prerequisites

### System Requirements
- **Node.js**: v18.0.0 or higher
- **Git**: Latest version
- **Operating System**: macOS, Linux, or Windows (WSL recommended)

### Development Tools
- **Foundry**: Ethereum development toolkit
- **VS Code**: Recommended IDE with Solidity extensions

## Installation

### 1. Install Foundry

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash

# Restart your terminal or source your profile
source ~/.bashrc  # or ~/.zshrc

# Install the latest version
foundryup
```

### 2. Clone the Repository

```bash
git clone <repository-url>
cd smart-contract
```

### 3. Install Dependencies

```bash
# Initialize and update git submodules
forge install

# Build the project
forge build
```

## Project Structure

```
├── .github/                    # GitHub configuration and documentation
│   ├── copilot-instruction.md  # Development guidelines
│   └── implementation-checklist.md  # Phase-by-phase implementation plan
├── src/                        # Solidity smart contracts
│   ├── AccessControl.sol       # Role-based access control
│   ├── InvoiceNFT.sol         # ERC-721 invoice/receivable tokens
│   ├── PaymentEscrow.sol      # Payment escrow management
│   ├── PaymentOracle.sol      # Payment verification and billing
│   ├── InvestmentPool.sol     # Individual pool management
│   └── PoolManager.sol        # Pool creation and bundling
├── test/                       # Foundry test files
│   ├── AccessControl.t.sol
│   ├── InvoiceNFT.t.sol
│   ├── PaymentEscrow.t.sol
│   ├── PaymentOracle.t.sol
│   ├── InvestmentPool.t.sol
│   └── PoolManager.t.sol
├── script/                     # Deployment scripts
│   └── Deploy.s.sol
├── foundry.toml               # Foundry configuration
└── README.md                  # This file
```

## Development Workflow

### Running Tests

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract ContractNFT

# Run specific test function
forge test --match-test testMintContract

# Run tests with gas reporting
forge test --gas-report
```

### Building Contracts

```bash
# Compile all contracts
forge build

# Compile with optimizations
forge build --optimize
```

### Code Coverage

```bash
# Generate coverage report
forge coverage

# Generate detailed HTML coverage report
forge coverage --report lcov
genhtml lcov.info --output-directory coverage
```

### Deployment

```bash
# Deploy to local network (Anvil)
anvil  # Start local node in separate terminal
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet (example: Sepolia)
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

### Useful Commands

```bash
# Format code
forge fmt

# Check for security issues with Slither (if installed)
slither .

# Start local blockchain node
anvil

# Interact with contracts using cast
cast call <contract-address> "balanceOf(address)" <wallet-address>
```

## Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# RPC URLs
MAINNET_RPC_URL=your_mainnet_rpc_url
SEPOLIA_RPC_URL=your_sepolia_rpc_url
POLYGON_RPC_URL=your_polygon_rpc_url

# Private Keys (for deployment)
PRIVATE_KEY=your_private_key

# Etherscan API Keys (for verification)
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
```

### Foundry Configuration

The `foundry.toml` file contains project-specific settings:
- Solidity version: ^0.8.20
- Optimization enabled
- Test configurations
- Dependency remappings

## Smart Contract Architecture

### Core Contracts

1. **AccessControl**: Manages role-based permissions (Admin, Investment Manager, Exporter, Investor, Importer)
2. **InvoiceNFT**: ERC-721 implementation for invoice/receivable tokens
3. **PoolManager**: Creates and manages investment pools
4. **InvestmentPool**: Handles individual pool investments with 70%/100% funding thresholds
5. **PaymentEscrow**: Manages payment escrow and automated distribution
6. **PaymentOracle**: Verifies importer payments and triggers billing

### Workflow

1. **Exporters** submit invoices/receivables to platform
2. **System** mints NFT for each invoice (minting fee charged to exporter)
3. **System** generates payment links for importers
4. **Investment Manager** groups NFTs into pools by criteria
5. **Investors** invest in pools (partial or full)
6. **Pool becomes eligible** at 70% funding (manual withdrawal) or 100% (auto-disbursement)
7. **Importers** receive automated payment reminders
8. **Payments update** pool balance and status
9. **Funds distributed** when all importers pay: Platform 1% + Investors 104% + Exporters remainder

## Testing Strategy

- **Unit Tests**: Test individual contract functions
- **Integration Tests**: Test cross-contract interactions
- **End-to-End Tests**: Simulate complete user workflows
- **Security Tests**: Test access controls and edge cases
- **Gas Optimization Tests**: Monitor gas consumption

## Contributing

1. Follow the implementation phases in `.github/implementation-checklist.md`
2. Ensure all tests pass before submitting PRs
3. Maintain >90% test coverage
4. Follow Solidity best practices in `.github/copilot-instruction.md`
5. Document all public functions with NatSpec comments

## Security Considerations

- All contracts implement reentrancy protection
- Role-based access control on sensitive functions
- Input validation on all external functions
- Proper error handling with custom errors
- Regular security audits recommended

## Support

For questions and support, please refer to:
- Implementation checklist: `.github/implementation-checklist.md`
- Development guidelines: `.github/copilot-instruction.md`
- [Open an issue](link-to-issues)

---

**Status**: 🚧 Under Development - Phase 1 (Project Setup)

See [Implementation Checklist](.github/implementation-checklist.md) for current progress.