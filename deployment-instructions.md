# Export-Import Funding Platform - Step-by-Step Deployment Instructions

## Prerequisites

### 1. Development Environment Setup
- [x] Foundry installed (`curl -L https://foundry.paradigm.xyz | bash`)
- [x] Git repository cloned
- [x] Dependencies installed (`forge install`)
- [x] All tests passing (`forge test`)

### 2. Environment Configuration
Create `.env` file with required variables:

```bash
# Required for all deployments
PRIVATE_KEY=0x...                    # Deployer private key
PLATFORM_ADMIN=0x...                # Platform administrator address

# Network-specific
LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
LISK_API_KEY=...                     # For contract verification

# Optional initial setup
INITIAL_EXPORTER=0x...
INITIAL_INVESTOR=0x...
INITIAL_ORACLE=0x...
```

## Phase 10 Deployment Process

### Step 1: Local Development Testing

1. **Start Local Blockchain**
   ```bash
   # Terminal 1: Start Anvil
   anvil
   ```

2. **Deploy Locally**
   ```bash
   # Terminal 2: Deploy contracts
   forge script script/DeployLocal.s.sol \
       --rpc-url http://localhost:8545 \
       --broadcast
   ```

3. **Capture Deployment Addresses**
   ```bash
   # Save the output addresses from deployment
   export ACCESS_CONTROL=0x...
   export INVOICE_NFT=0x...
   export POOL_NFT=0x...
   export POOL_FUNDING_MANAGER=0x...
   export PAYMENT_ORACLE=0x...
   export PLATFORM_ANALYTICS=0x...
   export PLATFORM_ADMIN=0x...
   ```

4. **Run Deployment Validation Tests**
   ```bash
   forge script script/DeploymentTest.s.sol \
       --rpc-url http://localhost:8545 \
       --broadcast
   ```

### Step 2: Testnet Deployment Preparation

1. **Verify Local Test Results**
   - [ ] All contracts deployed successfully
   - [ ] Role assignments working
   - [ ] Invoice creation and management
   - [ ] Pool creation and funding
   - [ ] Investment flow working
   - [ ] Analytics system operational

2. **Prepare Testnet Configuration**
   ```bash
   # Add to .env file
   NETWORK=lisk-sepolia
   LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
   LISK_API_KEY=your_blockscout_api_key
   ```

3. **Fund Deployer Account**
   - Get ETH from Lisk Sepolia faucet
   - Ensure sufficient balance for deployment and verification

### Step 3: Testnet Deployment (PENDING TEAM APPROVAL)

> ⚠️ **IMPORTANT**: This step is currently pending team confirmation. Do not proceed without approval.

When ready to deploy:

```bash
# Deploy to Lisk Sepolia Testnet
forge script script/Deploy.s.sol \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $LISK_API_KEY \
    --chain-id 4202
```

### Step 4: Post-Deployment Verification

1. **Verify Contract Addresses**
   ```bash
   # Check all contracts are deployed
   cast code $ACCESS_CONTROL --rpc-url $LISK_SEPOLIA_RPC_URL
   cast code $INVOICE_NFT --rpc-url $LISK_SEPOLIA_RPC_URL
   cast code $POOL_NFT --rpc-url $LISK_SEPOLIA_RPC_URL
   cast code $POOL_FUNDING_MANAGER --rpc-url $LISK_SEPOLIA_RPC_URL
   cast code $PAYMENT_ORACLE --rpc-url $LISK_SEPOLIA_RPC_URL
   cast code $PLATFORM_ANALYTICS --rpc-url $LISK_SEPOLIA_RPC_URL
   ```

2. **Run Testnet Validation**
   ```bash
   forge script script/DeploymentTest.s.sol \
       --rpc-url $LISK_SEPOLIA_RPC_URL \
       --broadcast
   ```

3. **Verify on Block Explorer**
   - Check contracts on https://sepolia-blockscout.lisk.com
   - Verify source code is published
   - Test contract interactions via web interface

### Step 5: Production Configuration

1. **Set Up Multi-Sig Administration** (Recommended)
   ```bash
   # Transfer admin role to multi-sig wallet
   cast send $ACCESS_CONTROL \
       "transferPlatformAdmin(address)" $MULTISIG_WALLET \
       --private-key $PRIVATE_KEY \
       --rpc-url $LISK_SEPOLIA_RPC_URL
   ```

2. **Grant Initial Roles**
   ```bash
   # Grant exporter role
   cast send $ACCESS_CONTROL \
       "grantExporterRole(address)" $EXPORTER_ADDRESS \
       --private-key $PRIVATE_KEY \
       --rpc-url $LISK_SEPOLIA_RPC_URL

   # Grant investor role
   cast send $ACCESS_CONTROL \
       "grantInvestorRole(address)" $INVESTOR_ADDRESS \
       --private-key $PRIVATE_KEY \
       --rpc-url $LISK_SEPOLIA_RPC_URL

   # Authorize oracle
   cast send $PAYMENT_ORACLE \
       "authorizeOracle(address)" $ORACLE_ADDRESS \
       --private-key $PRIVATE_KEY \
       --rpc-url $LISK_SEPOLIA_RPC_URL
   ```

3. **Initialize Analytics**
   ```bash
   # Update platform metrics
   cast send $PLATFORM_ANALYTICS \
       "updatePlatformMetrics()" \
       --private-key $PRIVATE_KEY \
       --rpc-url $LISK_SEPOLIA_RPC_URL
   ```

## Deployment Checklist

### Pre-Deployment
- [ ] All tests passing locally
- [ ] Security audit completed
- [ ] Environment variables configured
- [ ] Deployer account funded
- [ ] Team approval received
- [ ] Multi-sig wallet prepared (if applicable)

### During Deployment
- [ ] Local deployment successful
- [ ] Local validation tests pass
- [ ] Testnet deployment successful
- [ ] Contract verification successful
- [ ] All contract addresses recorded

### Post-Deployment
- [ ] Testnet validation tests pass
- [ ] Block explorer verification complete
- [ ] Initial roles granted
- [ ] Platform configuration verified
- [ ] Analytics system initialized
- [ ] Documentation updated with addresses
- [ ] Frontend configuration updated
- [ ] Monitoring systems configured

## Contract Addresses Registry

### Local Development (Anvil)
```
Network: Local Anvil
Chain ID: 31337
Platform Admin: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

PlatformAccessControl:  [Address from deployment]
InvoiceNFT:            [Address from deployment]  
PoolNFT:               [Address from deployment]
PoolFundingManager:    [Address from deployment]
PaymentOracle:         [Address from deployment]
PlatformAnalytics:     [Address from deployment]
```

### Lisk Sepolia Testnet (PENDING)
```
Network: Lisk Sepolia
Chain ID: 4202
RPC URL: https://rpc.sepolia-api.lisk.com
Explorer: https://sepolia-blockscout.lisk.com

PlatformAccessControl:  [PENDING DEPLOYMENT]
InvoiceNFT:            [PENDING DEPLOYMENT]
PoolNFT:               [PENDING DEPLOYMENT]
PoolFundingManager:    [PENDING DEPLOYMENT]
PaymentOracle:         [PENDING DEPLOYMENT]
PlatformAnalytics:     [PENDING DEPLOYMENT]
```

## Emergency Procedures

### Deployment Failure Recovery
1. Check transaction status and gas usage
2. Verify network connectivity and RPC endpoints
3. Ensure sufficient balance for gas fees
4. Retry deployment with higher gas limit if needed

### Contract Verification Failure
1. Check API key and network configuration
2. Verify constructor parameters match deployment
3. Ensure source code is identical to deployed bytecode
4. Try manual verification via block explorer

### Role Assignment Issues
1. Verify deployer has admin privileges
2. Check address format and validity
3. Ensure contracts are deployed and accessible
4. Test with different gas settings

## Next Steps After Deployment

1. **Frontend Integration**
   - Update contract addresses in frontend configuration
   - Test all user flows end-to-end
   - Verify event listening and real-time updates

2. **API Integration**
   - Update backend services with new contract addresses
   - Test oracle payment confirmation workflows
   - Verify analytics data collection

3. **Monitoring Setup**
   - Configure contract event monitoring
   - Set up alerts for unusual activity
   - Implement automated health checks

4. **User Onboarding**
   - Create user guides for each role type
   - Prepare demo scenarios for testing
   - Set up support procedures

---

**Status**: Phase 10 preparation completed. Ready for team review and testnet deployment approval.