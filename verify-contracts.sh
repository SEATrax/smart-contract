#!/bin/bash

# Verify Smart Contracts on Lisk Sepolia Blockscout
# Usage: ./verify-contracts.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contract addresses from latest deployment
ACCESS_CONTROL="0x6dA6C2Afcf8f2a1F31fC0eCc4C037C0b6317bA2F"
INVOICE_NFT="0x8Da2dF6050158ae8B058b90B37851323eFd69E16"
POOL_NFT="0x317Ce254731655E19932b9EFEAf7eeA31F0775ad"
POOL_FUNDING_MANAGER="0xbD5f292F75D22996E7A4DD277083c75aB29ff45C"
PAYMENT_ORACLE="0x7894728174E53Df9Fec402De07d80652659296a8"
PLATFORM_ANALYTICS="0xb77C5C42b93ec46A323137B64586F0F8dED987A9"

# Network configuration
RPC_URL="https://rpc.sepolia-api.lisk.com"
VERIFIER_URL="https://sepolia-blockscout.lisk.com/api/"

echo -e "${YELLOW}🚀 Starting contract verification on Lisk Sepolia Blockscout...${NC}"
echo ""

# Verify PlatformAccessControl
echo -e "${YELLOW}1/6 Verifying PlatformAccessControl...${NC}"
forge verify-contract \
  --rpc-url "$RPC_URL" \
  --verifier blockscout \
  --verifier-url "$VERIFIER_URL" \
  "$ACCESS_CONTROL" \
  src/AccessControl.sol:PlatformAccessControl

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PlatformAccessControl verified successfully${NC}"
else
    echo -e "${RED}❌ PlatformAccessControl verification failed${NC}"
fi
echo ""

# Verify InvoiceNFT
echo -e "${YELLOW}2/6 Verifying InvoiceNFT...${NC}"
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" "$ACCESS_CONTROL")
forge verify-contract \
  --rpc-url "$RPC_URL" \
  --verifier blockscout \
  --verifier-url "$VERIFIER_URL" \
  --constructor-args "$CONSTRUCTOR_ARGS" \
  "$INVOICE_NFT" \
  src/InvoiceNFT.sol:InvoiceNFT

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ InvoiceNFT verified successfully${NC}"
else
    echo -e "${RED}❌ InvoiceNFT verification failed${NC}"
fi
echo ""

# Verify PoolNFT
echo -e "${YELLOW}3/6 Verifying PoolNFT...${NC}"
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address)" "$ACCESS_CONTROL" "$INVOICE_NFT")
forge verify-contract \
  --rpc-url "$RPC_URL" \
  --verifier blockscout \
  --verifier-url "$VERIFIER_URL" \
  --constructor-args "$CONSTRUCTOR_ARGS" \
  "$POOL_NFT" \
  src/PoolNFT.sol:PoolNFT

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PoolNFT verified successfully${NC}"
else
    echo -e "${RED}❌ PoolNFT verification failed${NC}"
fi
echo ""

# Verify PoolFundingManager
echo -e "${YELLOW}4/6 Verifying PoolFundingManager...${NC}"
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address,address)" "$ACCESS_CONTROL" "$INVOICE_NFT" "$POOL_NFT")
forge verify-contract \
  --rpc-url "$RPC_URL" \
  --verifier blockscout \
  --verifier-url "$VERIFIER_URL" \
  --constructor-args "$CONSTRUCTOR_ARGS" \
  "$POOL_FUNDING_MANAGER" \
  src/PoolFundingManager.sol:PoolFundingManager

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PoolFundingManager verified successfully${NC}"
else
    echo -e "${RED}❌ PoolFundingManager verification failed${NC}"
fi
echo ""

# Verify PaymentOracle
echo -e "${YELLOW}5/6 Verifying PaymentOracle...${NC}"
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address,address,address)" "$ACCESS_CONTROL" "$INVOICE_NFT" "$POOL_NFT" "$POOL_FUNDING_MANAGER")
forge verify-contract \
  --rpc-url "$RPC_URL" \
  --verifier blockscout \
  --verifier-url "$VERIFIER_URL" \
  --constructor-args "$CONSTRUCTOR_ARGS" \
  "$PAYMENT_ORACLE" \
  src/PaymentOracle.sol:PaymentOracle

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PaymentOracle verified successfully${NC}"
else
    echo -e "${RED}❌ PaymentOracle verification failed${NC}"
fi
echo ""

# Verify PlatformAnalytics
echo -e "${YELLOW}6/6 Verifying PlatformAnalytics...${NC}"
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address,address,address,address)" "$ACCESS_CONTROL" "$INVOICE_NFT" "$POOL_NFT" "$POOL_FUNDING_MANAGER" "$PAYMENT_ORACLE")
forge verify-contract \
  --rpc-url "$RPC_URL" \
  --verifier blockscout \
  --verifier-url "$VERIFIER_URL" \
  --constructor-args "$CONSTRUCTOR_ARGS" \
  "$PLATFORM_ANALYTICS" \
  src/PlatformAnalytics.sol:PlatformAnalytics

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PlatformAnalytics verified successfully${NC}"
else
    echo -e "${RED}❌ PlatformAnalytics verification failed${NC}"
fi
echo ""

echo -e "${GREEN}🎉 Contract verification process completed!${NC}"
echo -e "${YELLOW}📋 Check verification status at: https://sepolia-blockscout.lisk.com${NC}"
echo ""
echo -e "${YELLOW}📝 Contract Addresses:${NC}"
echo -e "  PlatformAccessControl: $ACCESS_CONTROL"
echo -e "  InvoiceNFT: $INVOICE_NFT"
echo -e "  PoolNFT: $POOL_NFT"
echo -e "  PoolFundingManager: $POOL_FUNDING_MANAGER"
echo -e "  PaymentOracle: $PAYMENT_ORACLE"
echo -e "  PlatformAnalytics: $PLATFORM_ANALYTICS"