#!/bin/bash

echo "=== Testing PaymentOracle Issues ==="

echo "1. Testing compilation..."
forge build > /tmp/build.log 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation failed:"
    tail -20 /tmp/build.log
    exit 1
fi

echo "2. Testing individual failing tests..."

echo "Test: test_ManualSettlement_Success"
forge test --match-test test_ManualSettlement_Success -vvv

echo "Test: test_PoolSettlement_Success" 
forge test --match-test test_PoolSettlement_Success -vvv

echo "Test: test_ResolvePaymentDispute_Valid"
forge test --match-test test_ResolvePaymentDispute_Valid -vvv

echo "Test: test_SubmitPaymentConfirmation_MultipleOracles"
forge test --match-test test_SubmitPaymentConfirmation_MultipleOracles -vvv

echo "Test: test_SubmitPaymentConfirmation_RevertAlreadyConfirmed"
forge test --match-test test_SubmitPaymentConfirmation_RevertAlreadyConfirmed -vvv