# Export-Import Funding Platform - Deployment Configuration

## Environment Variables

Create a `.env` file in the project root with the following variables:

### Required Variables
```bash
# Deployment key (keep secure!)
PRIVATE_KEY=0x...

# Network configuration
NETWORK=local|lisk-sepolia|mainnet

# Platform administrator (has all admin privileges)
PLATFORM_ADMIN=0x...

# RPC URLs
LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
MAINNET_RPC_URL=https://rpc.api.lisk.com

# Block explorer API keys (for contract verification)
LISK_API_KEY=your_blockscout_api_key
```

### Optional Variables (for initial setup)
```bash
# Initial roles (optional - can be granted later)
INITIAL_EXPORTER=0x...
INITIAL_INVESTOR=0x...
INITIAL_ORACLE=0x...

# Custom configuration (optional)
PLATFORM_FEE_RATE=100           # 1% in basis points (default)
INVESTOR_YIELD_RATE=400         # 4% in basis points (default)
MIN_INVESTMENT=1000000000000000000000  # 1000 tokens (default)
```

## Deployment Scripts

### 1. Local Deployment (Anvil/Testing)
```bash
# Start local node
anvil

# Deploy to local network
forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 2. Lisk Sepolia Testnet Deployment
```bash
# Deploy to Lisk Sepolia
forge script script/Deploy.s.sol \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $LISK_API_KEY
```

### 3. Mainnet Deployment
```bash
# Deploy to Lisk Mainnet (use with caution)
forge script script/Deploy.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $LISK_API_KEY \
    --gas-limit 10000000
```

## Contract Verification

After deployment, verify contracts on block explorer:

```bash
# Verify AccessControl
forge verify-contract $ACCESS_CONTROL PlatformAccessControl \
    --constructor-args $(cast abi-encode "constructor(address)" $PLATFORM_ADMIN) \
    --etherscan-api-key $LISK_API_KEY \
    --chain-id 4202

# Verify InvoiceNFT
forge verify-contract $INVOICE_NFT InvoiceNFT \
    --constructor-args $(cast abi-encode "constructor(address)" $ACCESS_CONTROL) \
    --etherscan-api-key $LISK_API_KEY \
    --chain-id 4202

# Verify PoolNFT
forge verify-contract $POOL_NFT PoolNFT \
    --constructor-args $(cast abi-encode "constructor(address,address)" $ACCESS_CONTROL $INVOICE_NFT) \
    --etherscan-api-key $LISK_API_KEY \
    --chain-id 4202

# Verify PoolFundingManager
forge verify-contract $POOL_FUNDING_MANAGER PoolFundingManager \
    --constructor-args $(cast abi-encode "constructor(address,address,address)" $ACCESS_CONTROL $INVOICE_NFT $POOL_NFT) \
    --etherscan-api-key $LISK_API_KEY \
    --chain-id 4202

# Verify PaymentOracle
forge verify-contract $PAYMENT_ORACLE PaymentOracle \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address)" $ACCESS_CONTROL $INVOICE_NFT $POOL_NFT $POOL_FUNDING_MANAGER) \
    --etherscan-api-key $LISK_API_KEY \
    --chain-id 4202

# Verify PlatformAnalytics
forge verify-contract $PLATFORM_ANALYTICS PlatformAnalytics \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" $ACCESS_CONTROL $INVOICE_NFT $POOL_NFT $POOL_FUNDING_MANAGER $PAYMENT_ORACLE) \
    --etherscan-api-key $LISK_API_KEY \
    --chain-id 4202
```

## Post-Deployment Setup

### 1. Grant Initial Roles
```bash
# Grant exporter role
cast send $ACCESS_CONTROL "grantExporterRole(address)" $EXPORTER_ADDRESS \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Grant investor role
cast send $ACCESS_CONTROL "grantInvestorRole(address)" $INVESTOR_ADDRESS \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Authorize oracle
cast send $PAYMENT_ORACLE "authorizeOracle(address)" $ORACLE_ADDRESS \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 2. Initial Analytics Update
```bash
# Update platform metrics
cast send $PLATFORM_ANALYTICS "updatePlatformMetrics()" \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 3. Verify Deployment
```bash
# Check contract addresses
echo "Platform Admin: $(cast call $ACCESS_CONTROL "platformAdmin()")"
echo "Invoice NFT Name: $(cast call $INVOICE_NFT "name()")"
echo "Pool NFT Symbol: $(cast call $POOL_NFT "symbol()")"

# Check platform configuration
echo "Platform Fee Rate: $(cast call $POOL_FUNDING_MANAGER "PLATFORM_FEE_RATE()")"
echo "Investor Yield Rate: $(cast call $POOL_FUNDING_MANAGER "INVESTOR_YIELD_RATE()")"
echo "Min Investment: $(cast call $POOL_FUNDING_MANAGER "MIN_INVESTMENT()")"
```

## Network Configuration

### Lisk Sepolia Testnet
- Chain ID: 4202
- RPC URL: https://rpc.sepolia-api.lisk.com
- Block Explorer: https://sepolia-blockscout.lisk.com
- Faucet: Available through Lisk Portal

### Lisk Mainnet
- Chain ID: 1135
- RPC URL: https://rpc.api.lisk.com
- Block Explorer: https://blockscout.lisk.com

## Security Considerations

### Pre-Deployment Checklist
- [ ] Audit all contract code
- [ ] Verify constructor parameters
- [ ] Test deployment on local network
- [ ] Test deployment on testnet
- [ ] Verify all contract interactions
- [ ] Check gas costs and optimization
- [ ] Backup deployment private key securely
- [ ] Prepare emergency response procedures

### Post-Deployment Security
- [ ] Transfer admin roles to multi-sig wallet
- [ ] Set up monitoring and alerting
- [ ] Document emergency procedures
- [ ] Regular security reviews
- [ ] Backup important transactions

## Troubleshooting

### Common Issues

1. **Deployment Fails with "Insufficient Gas"**
   - Increase gas limit: `--gas-limit 10000000`
   - Check network congestion and gas prices

2. **Contract Verification Fails**
   - Ensure correct constructor parameters
   - Check API key and network configuration
   - Verify contract source matches deployed bytecode

3. **Role Assignment Fails**
   - Ensure deployer has admin role
   - Check address format and validity
   - Verify contract addresses are correct

### Debug Commands
```bash
# Check deployment transaction
cast tx $TX_HASH --rpc-url $RPC_URL

# Check contract code
cast code $CONTRACT_ADDRESS --rpc-url $RPC_URL

# Test contract call
cast call $CONTRACT_ADDRESS "function()" --rpc-url $RPC_URL

# Estimate gas for transaction
cast estimate $CONTRACT_ADDRESS "function()" --rpc-url $RPC_URL
```