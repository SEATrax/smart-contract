// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/AccessControl.sol";
import "../src/InvoiceNFT.sol";
import "../src/PoolNFT.sol";
import "../src/PoolFundingManager.sol";
import "../src/PaymentOracle.sol";

/**
 * @title Phase6Integration
 * @notice Integration tests for Phase 6 - Payment & Settlement functionality
 * @dev Tests complete workflow from investment to payment confirmation to settlement
 */
contract Phase6IntegrationTest is Test {
    PlatformAccessControl accessControl;
    InvoiceNFT invoiceNft;
    PoolNFT poolNft;
    PoolFundingManager fundingManager;
    PaymentOracle paymentOracle;

    address admin = makeAddr("admin");
    address exporter1 = makeAddr("exporter1");
    address exporter2 = makeAddr("exporter2");
    address investor1 = makeAddr("investor1");
    address investor2 = makeAddr("investor2");
    address oracle1 = makeAddr("oracle1");
    address oracle2 = makeAddr("oracle2");

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy all contracts
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        poolNft = new PoolNFT(address(accessControl), address(invoiceNft));
        fundingManager = new PoolFundingManager(
            address(accessControl),
            address(invoiceNft),
            address(poolNft)
        );
        paymentOracle = new PaymentOracle(
            address(accessControl),
            address(invoiceNft),
            address(poolNft),
            address(fundingManager)
        );
        
        // Setup roles
        accessControl.grantExporterRole(exporter1);
        accessControl.grantExporterRole(exporter2);
        accessControl.grantInvestorRole(investor1);
        accessControl.grantInvestorRole(investor2);
        accessControl.grantAdminRole(address(fundingManager));
        
        // Setup oracles
        paymentOracle.authorizeOracle(oracle1);
        paymentOracle.authorizeOracle(oracle2);
        
        vm.stopPrank();
    }

    /**
     * @notice Test complete Phase 6 workflow: Payment confirmation and settlement
     */
    function test_Phase6_CompletePaymentAndSettlement() public {
        console2.log("=== Phase 6 Integration Test: Payment & Settlement ===");
        
        // Step 1: Create invoices
        vm.startPrank(exporter1);
        uint256 invoice1 = invoiceNft.mintInvoice(
            "Exporter Corp A",
            "Importer Inc",
            50000e18,  // $50k shipping
            35000e18,  // $35k loan
            block.timestamp + 30 days
        );
        invoiceNft.finalizeInvoice(invoice1);
        
        uint256 invoice2 = invoiceNft.mintInvoice(
            "Exporter Corp A",
            "Importer Inc",
            30000e18,  // $30k shipping  
            21000e18,  // $21k loan
            block.timestamp + 35 days
        );
        invoiceNft.finalizeInvoice(invoice2);
        vm.stopPrank();

        vm.startPrank(exporter2);
        uint256 invoice3 = invoiceNft.mintInvoice(
            "Exporter Corp B", 
            "Importer Inc",
            40000e18,  // $40k shipping
            28000e18,  // $28k loan
            block.timestamp + 25 days
        );
        invoiceNft.finalizeInvoice(invoice3);
        vm.stopPrank();

        console2.log("[OK] Created 3 invoices with total loans: 84k, total shipping: 120k");
        
        // Step 2: Create pool with all invoices
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](3);
        invoiceIds[0] = invoice1;
        invoiceIds[1] = invoice2; 
        invoiceIds[2] = invoice3;
        
        uint256 poolId = poolNft.createPool("Q4 Export Pool", invoiceIds);
        poolNft.finalizePool(poolId);
        vm.stopPrank();
        
        console2.log("[OK] Created pool with 3 invoices");
        
        // Step 3: Investors fund the pool
        vm.startPrank(investor1);
        fundingManager.investInPool(poolId, 50000e18); // $50k
        vm.stopPrank();
        
        vm.startPrank(investor2);
        fundingManager.investInPool(poolId, 40000e18); // $40k
        vm.stopPrank();
        
        // Total investment: $90k (exceeds $84k loan amount - should be capped)
        uint256 totalInvestment = fundingManager.poolTotalInvestment(poolId);
        assertEq(totalInvestment, 90000e18);
        console2.log("[OK] Pool funded with $90k total investment");
        
        // Step 4: Allocate funds to invoices
        vm.startPrank(admin);
        fundingManager.allocateFundsToInvoices(poolId);
        vm.stopPrank();
        
        // Verify pool status and invoice funding
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Funded));
        
        // Check invoices are funded
        InvoiceNFT.Invoice memory inv1 = invoiceNft.getInvoice(invoice1);
        InvoiceNFT.Invoice memory inv2 = invoiceNft.getInvoice(invoice2);
        InvoiceNFT.Invoice memory inv3 = invoiceNft.getInvoice(invoice3);
        
        assertEq(uint8(inv1.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
        assertEq(uint8(inv2.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
        assertEq(uint8(inv3.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
        
        console2.log("[OK] Pool funded and invoices allocated");
        
        // Step 5: Payment confirmations via oracle
        bytes32 paymentHash1 = keccak256("payment_tx_invoice1_abc123");
        bytes32 paymentHash2 = keccak256("payment_tx_invoice2_def456");  
        bytes32 paymentHash3 = keccak256("payment_tx_invoice3_ghi789");
        
        // Confirm invoice 1 payment
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(invoice1, paymentHash1, 50000e18);
        vm.stopPrank();
        
        vm.startPrank(oracle2);
        paymentOracle.submitPaymentConfirmation(invoice1, paymentHash1, 50000e18);
        vm.stopPrank();
        
        // Confirm invoice 2 payment
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(invoice2, paymentHash2, 30000e18);
        vm.stopPrank();
        
        vm.startPrank(oracle2);
        paymentOracle.submitPaymentConfirmation(invoice2, paymentHash2, 30000e18);
        vm.stopPrank();
        
        // Confirm invoice 3 payment  
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(invoice3, paymentHash3, 40000e18);
        vm.stopPrank();
        
        vm.startPrank(oracle2);
        paymentOracle.submitPaymentConfirmation(invoice3, paymentHash3, 40000e18);
        vm.stopPrank();
        
        console2.log("[OK] All invoice payments confirmed via oracle system");
        
        // Step 6: Verify automatic settlement triggered
        assertTrue(paymentOracle.poolsPendingSettlement(poolId));
        
        PoolNFT.Pool memory settledPool = poolNft.getPool(poolId);
        assertEq(uint8(settledPool.status), uint8(PoolNFT.PoolStatus.Settling));
        
        console2.log("[OK] Pool automatically transitioned to Settlement");
        
        // Step 7: Verify all invoices marked as paid
        InvoiceNFT.Invoice memory paidInv1 = invoiceNft.getInvoice(invoice1);
        InvoiceNFT.Invoice memory paidInv2 = invoiceNft.getInvoice(invoice2);
        InvoiceNFT.Invoice memory paidInv3 = invoiceNft.getInvoice(invoice3);
        
        assertEq(uint8(paidInv1.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
        assertEq(uint8(paidInv2.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
        assertEq(uint8(paidInv3.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
        
        console2.log("[OK] All invoices marked as paid");
        
        // Step 8: Verify payment records
        PaymentOracle.PaymentRecord memory record1 = paymentOracle.getPaymentRecord(invoice1);
        PaymentOracle.PaymentRecord memory record2 = paymentOracle.getPaymentRecord(invoice2);
        PaymentOracle.PaymentRecord memory record3 = paymentOracle.getPaymentRecord(invoice3);
        
        assertTrue(record1.isConfirmed);
        assertTrue(record2.isConfirmed);
        assertTrue(record3.isConfirmed);
        
        assertEq(record1.amountPaid, 50000e18);
        assertEq(record2.amountPaid, 30000e18);
        assertEq(record3.amountPaid, 40000e18);
        
        console2.log("[OK] Payment records properly stored");
        
        // Step 9: Verify investor tracking is maintained  
        assertEq(fundingManager.investorPoolInvestments(poolId, investor1), 50000e18);
        assertEq(fundingManager.investorPoolInvestments(poolId, investor2), 40000e18);
        
        console2.log("[OK] Investor investments tracked through settlement");
        
        console2.log("✅ Phase 6 Integration Test COMPLETED SUCCESSFULLY");
        console2.log("✅ Payment Oracle System: WORKING");
        console2.log("✅ Automated Settlement: WORKING");
        console2.log("✅ Multi-Oracle Confirmation: WORKING");
        console2.log("✅ Cross-Contract Integration: WORKING");
    }

    /**
     * @notice Test manual settlement workflow
     */
    function test_Phase6_ManualSettlement() public {
        console2.log("=== Phase 6 Manual Settlement Test ===");
        
        // Create simple test case
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Test Corp",
            "Import Inc",
            10000e18,  // $10k shipping
            7000e18,   // $7k loan
            block.timestamp + 30 days
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();

        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Manual Test Pool", invoiceIds);
        poolNft.finalizePool(poolId);
        vm.stopPrank();

        vm.startPrank(investor1);
        fundingManager.investInPool(poolId, 7000e18);
        vm.stopPrank();

        vm.startPrank(admin);
        fundingManager.allocateFundsToInvoices(poolId);
        
        // Manually confirm payment via InvoiceNFT
        invoiceNft.confirmPayment(invoiceId);
        
        // Manually trigger settlement
        paymentOracle.manualSettlement(poolId);
        
        // Verify settlement
        assertTrue(paymentOracle.poolsPendingSettlement(poolId));
        
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Settling));
        
        vm.stopPrank();
        
        console2.log("✅ Manual Settlement Test COMPLETED SUCCESSFULLY");
    }

    /**
     * @notice Test dispute resolution workflow
     */
    function test_Phase6_PaymentDispute() public {
        console2.log("=== Phase 6 Payment Dispute Test ===");
        
        // Setup test case
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Dispute Corp",
            "Import Inc", 
            5000e18,   // $5k shipping
            3500e18,   // $3.5k loan
            block.timestamp + 30 days
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();

        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Dispute Pool", invoiceIds);
        poolNft.finalizePool(poolId);
        vm.stopPrank();

        vm.startPrank(investor1);
        fundingManager.investInPool(poolId, 3500e18);
        vm.stopPrank();

        vm.startPrank(admin);
        fundingManager.allocateFundsToInvoices(poolId);
        vm.stopPrank();

        // Submit disputed payment
        bytes32 paymentHash = keccak256("disputed_payment_xyz");
        
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(invoiceId, paymentHash, 5000e18);
        vm.stopPrank();

        // Dispute the payment
        vm.startPrank(admin);
        paymentOracle.disputePayment(invoiceId, paymentHash);
        
        PaymentOracle.PaymentRecord memory record = paymentOracle.getPaymentRecord(invoiceId);
        assertTrue(record.isDisputed);
        
        // Resolve dispute as invalid
        paymentOracle.resolvePaymentDispute(invoiceId, false);
        
        // Payment should be reset
        PaymentOracle.PaymentRecord memory resetRecord = paymentOracle.getPaymentRecord(invoiceId);
        assertEq(resetRecord.paymentHash, bytes32(0));
        
        vm.stopPrank();
        
        console2.log("✅ Payment Dispute Test COMPLETED SUCCESSFULLY");
    }
}