// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";
import {PaymentOracle} from "../src/PaymentOracle.sol";
import {PlatformAnalytics} from "../src/PlatformAnalytics.sol";

/**
 * @title Phase 8 Integration Tests
 * @notice Comprehensive end-to-end testing of the entire shipping invoice funding platform
 * @dev Tests full lifecycle scenarios from invoice creation to settlement with analytics
 */
contract Phase8IntegrationTest is Test {
    // Contracts
    PlatformAccessControl public accessControl;
    InvoiceNFT public invoiceNft;
    PoolNFT public poolNft;
    PoolFundingManager public fundingManager;
    PaymentOracle public paymentOracle;
    PlatformAnalytics public analytics;

    // Test actors
    address public admin = makeAddr("admin");
    address public exporter1 = makeAddr("exporter1");
    address public exporter2 = makeAddr("exporter2");
    address public investor1 = makeAddr("investor1");
    address public investor2 = makeAddr("investor2");
    address public investor3 = makeAddr("investor3");
    address public oracle1 = makeAddr("oracle1");
    address public oracle2 = makeAddr("oracle2");

    // Test constants
    uint256 constant INVOICE_AMOUNT = 100_000e18; // 100k USDC
    uint256 constant SHIPPING_AMOUNT = 80_000e18; // 80k USDC
    uint256 constant LARGE_INVESTMENT = 500_000e18; // 500k USDC
    uint256 constant MEDIUM_INVESTMENT = 250_000e18; // 250k USDC
    uint256 constant SMALL_INVESTMENT = 100_000e18; // 100k USDC

    // Events for testing
    event FullLifecycleCompleted(uint256 indexed poolId, uint256 totalInvestment, uint256 totalProfit);
    event MultiPoolScenarioCompleted(uint256 poolCount, uint256 totalTvl);
    event PerformanceTestCompleted(uint256 operationCount, uint256 gasUsed);

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
        
        analytics = new PlatformAnalytics(
            address(accessControl),
            address(invoiceNft),
            address(poolNft),
            address(fundingManager),
            address(paymentOracle)
        );

        // Grant roles
        accessControl.grantRole(accessControl.EXPORTER_ROLE(), exporter1);
        accessControl.grantRole(accessControl.EXPORTER_ROLE(), exporter2);
        accessControl.grantRole(accessControl.INVESTOR_ROLE(), investor1);
        accessControl.grantRole(accessControl.INVESTOR_ROLE(), investor2);
        accessControl.grantRole(accessControl.INVESTOR_ROLE(), investor3);
        
        // Authorize oracles
        paymentOracle.authorizeOracle(oracle1);
        paymentOracle.authorizeOracle(oracle2);

        vm.stopPrank();
    }

    /**
     * @notice Test complete lifecycle: invoice → pool → investment → withdrawal → payment → settlement
     * @dev This test validates the entire platform workflow with analytics tracking
     */
    function testFullLifecycleIntegration() public {
        console2.log("=== Starting Full Lifecycle Integration Test ===");
        
        uint256 startGas = gasleft();
        
        // Phase 1: Invoice Creation
        uint256[] memory invoiceIds = _createTestInvoices(exporter1, 3);
        console2.log("Created", invoiceIds.length, "invoices for pool");

        // Phase 2: Pool Creation  
        uint256 poolId = _createTestPool("Lifecycle Test Pool", invoiceIds);
        console2.log("Created pool", poolId, "with invoices bundled");
        
        // Finalize pool to start fundraising
        vm.prank(admin);
        poolNft.finalizePool(poolId);
        console2.log("Pool finalized and ready for fundraising");

        // Phase 3: Investment Phase
        uint256 totalInvestment = _performInvestments(poolId);
        console2.log("Total investment received:", totalInvestment);

        // Phase 4: Fund Allocation
        vm.prank(admin);
        fundingManager.allocateFundsToInvoices(poolId);
        console2.log("Funds allocated to invoices");

        // Phase 5: Exporter Withdrawals
        _performExporterWithdrawals(exporter1, invoiceIds);
        console2.log("Exporter withdrawals completed");

        // Phase 6: Payment Confirmations
        _performPaymentConfirmations(invoiceIds);
        console2.log("All invoices marked as paid");

        // Phase 7: Settlement (automatic after payments, but trigger profit distribution)
        vm.prank(admin);
        fundingManager.distributeProfits(poolId);
        console2.log("Pool settlement completed");

        // Phase 8: Analytics Validation
        _validateAnalyticsData(poolId, totalInvestment);
        console2.log("Analytics data validated");

        uint256 gasUsed = startGas - gasleft();
        emit FullLifecycleCompleted(poolId, totalInvestment, 0);
        
        console2.log("Full lifecycle completed - Gas used:", gasUsed);
        console2.log("=== Full Lifecycle Integration Test Complete ===");
    }

    /**
     * @notice Test multiple pools at different stages simultaneously
     */
    function testMultiPoolScenarios() public {
        console2.log("=== Starting Multi-Pool Scenarios Test ===");
        
        uint256[] memory poolIds = new uint256[](4);
        uint256 totalTvl = 0;

        // Pool 1: Just created (Open)
        uint256[] memory pool1Invoices = _createTestInvoices(exporter1, 2);
        poolIds[0] = _createTestPool("Pool 1 - Open", pool1Invoices);

        // Pool 2: Fundraising stage
        uint256[] memory pool2Invoices = _createTestInvoices(exporter1, 3);
        poolIds[1] = _createTestPool("Pool 2 - Fundraising", pool2Invoices);
        vm.prank(admin);
        poolNft.finalizePool(poolIds[1]); // Transition to Fundraising
        
        // Partial investment in Pool 2
        vm.prank(investor1);
        fundingManager.investInPool(poolIds[1], MEDIUM_INVESTMENT);
        totalTvl += MEDIUM_INVESTMENT;

        // Pool 3: Fully funded
        uint256[] memory pool3Invoices = _createTestInvoices(exporter2, 2);
        poolIds[2] = _createTestPool("Pool 3 - Funded", pool3Invoices);
        uint256 pool3Investment = _performInvestments(poolIds[2]);
        totalTvl += pool3Investment;

        vm.prank(admin);
        fundingManager.allocateFundsToInvoices(poolIds[2]);

        // Pool 4: Settlement ready (all invoices paid)
        uint256[] memory pool4Invoices = _createTestInvoices(exporter2, 1);
        poolIds[3] = _createTestPool("Pool 4 - Settlement", pool4Invoices);
        uint256 pool4Investment = _performInvestments(poolIds[3]);
        totalTvl += pool4Investment;

        vm.prank(admin);
        fundingManager.allocateFundsToInvoices(poolIds[3]);
        _performExporterWithdrawals(exporter2, pool4Invoices);
        _performPaymentConfirmations(pool4Invoices);

        // Validate different pool states
        assertEq(uint256(poolNft.getPool(poolIds[0]).status), uint256(PoolNFT.PoolStatus.Open));
        assertEq(uint256(poolNft.getPool(poolIds[1]).status), uint256(PoolNFT.PoolStatus.Fundraising));
        assertEq(uint256(poolNft.getPool(poolIds[2]).status), uint256(PoolNFT.PoolStatus.Funded));
        assertTrue(poolNft.getPool(poolIds[3]).status == PoolNFT.PoolStatus.Funded);

        // Test analytics across multiple pools
        PlatformAnalytics.PlatformMetrics memory metrics = analytics.getPlatformMetrics();
        assertGt(metrics.totalValueLocked, 0);
        assertEq(metrics.activePools, 4);

        emit MultiPoolScenarioCompleted(poolIds.length, totalTvl);
        console2.log("Multi-pool scenarios completed - Pools:", poolIds.length, "TVL:", totalTvl);
        console2.log("=== Multi-Pool Scenarios Test Complete ===");
    }

    /**
     * @notice Test edge cases and error conditions
     */
    function testEdgeCasesAndErrorConditions() public {
        console2.log("=== Starting Edge Cases Test ===");

        // Test 1: Partial funding scenarios (below 70% threshold)
        uint256[] memory invoiceIds = _createTestInvoices(exporter1, 2);
        uint256 poolId = _createTestPool("Partial Funding Pool", invoiceIds);
        
        // Invest only 50% of required amount
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        uint256 partialAmount = pool.totalLoanAmount / 2;
        
        vm.prank(investor1);
        fundingManager.investInPool(poolId, partialAmount);

        // Should not be able to allocate funds (below 70% threshold)
        vm.expectRevert();
        vm.prank(admin);
        fundingManager.allocateFundsToInvoices(poolId);

        console2.log("Verified 70% threshold protection");

        // Test 2: Over-investment scenario
        vm.prank(investor2);
        fundingManager.investInPool(poolId, pool.totalLoanAmount); // Now over 100%
        
        // Should be able to allocate now
        vm.prank(admin);
        fundingManager.allocateFundsToInvoices(poolId);

        console2.log("Verified over-investment handling");

        // Test 3: Premature withdrawal attempts
        vm.expectRevert();
        vm.prank(exporter1);
        invoiceNft.withdrawFunds(invoiceIds[0], SHIPPING_AMOUNT);

        console2.log("Verified premature withdrawal protection");

        // Test 4: Double payment prevention
        _performExporterWithdrawals(exporter1, invoiceIds);
        
        vm.prank(oracle1);
        paymentOracle.submitPaymentConfirmation(invoiceIds[0], keccak256("payment1"), SHIPPING_AMOUNT);
        
        // Try to confirm same payment again
        vm.expectRevert();
        vm.prank(oracle1);
        paymentOracle.submitPaymentConfirmation(invoiceIds[0], keccak256("payment1"), SHIPPING_AMOUNT);

        console2.log("Verified double payment prevention");

        console2.log("=== Edge Cases Test Complete ===");
    }

    /**
     * @notice Test performance with large-scale scenarios
     */
    function testPerformanceAndScaling() public {
        console2.log("=== Starting Performance Test ===");
        
        uint256 startGas = gasleft();
        uint256 operationCount = 0;

        // Create large pool with many invoices
        uint256[] memory largeInvoiceSet = _createTestInvoices(exporter1, 10);
        operationCount += largeInvoiceSet.length;

        uint256 largePoolId = _createTestPool("Performance Test Pool", largeInvoiceSet);
        operationCount += 1;

        // Multiple investors investing
        uint256[] memory investments = new uint256[](3);
        investments[0] = LARGE_INVESTMENT;
        investments[1] = MEDIUM_INVESTMENT;
        investments[2] = SMALL_INVESTMENT;

        address[] memory investors = new address[](3);
        investors[0] = investor1;
        investors[1] = investor2;
        investors[2] = investor3;

        for (uint256 i = 0; i < investors.length; i++) {
            vm.prank(investors[i]);
            fundingManager.investInPool(largePoolId, investments[i]);
            operationCount += 1;
        }

        // Batch operations
        vm.prank(admin);
        fundingManager.allocateFundsToInvoices(largePoolId);
        operationCount += largeInvoiceSet.length;

        // Batch withdrawals
        _performExporterWithdrawals(exporter1, largeInvoiceSet);
        operationCount += largeInvoiceSet.length;

        // Analytics updates
        vm.prank(admin);
        analytics.updatePoolPerformance(largePoolId);
        operationCount += 1;

        uint256 gasUsed = startGas - gasleft();
        emit PerformanceTestCompleted(operationCount, gasUsed);

        console2.log("Performance test completed");
        console2.log("Operations:", operationCount, "Gas used:", gasUsed);
        console2.log("Average gas per operation:", gasUsed / operationCount);
        console2.log("=== Performance Test Complete ===");
    }

    /**
     * @notice Test gas optimization across all contracts
     */
    function testGasOptimization() public {
        console2.log("=== Starting Gas Optimization Analysis ===");

        // Test individual operations for gas usage
        uint256 gasSnapshot;
        
        // Invoice creation gas
        gasSnapshot = gasleft();
        vm.prank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Gas Test Exporter",
            "Gas Test Importer", 
            INVOICE_AMOUNT,
            SHIPPING_AMOUNT,
            block.timestamp + 30 days
        );
        uint256 invoiceCreationGas = gasSnapshot - gasleft();
        console2.log("Invoice creation gas:", invoiceCreationGas);

        // Finalize invoice
        vm.prank(exporter1);
        invoiceNft.finalizeInvoice(invoiceId);

        // Pool creation gas
        uint256[] memory singleInvoice = new uint256[](1);
        singleInvoice[0] = invoiceId;
        
        gasSnapshot = gasleft();
        vm.prank(admin);
        uint256 poolId = poolNft.createPool(
            "Gas Test Pool",
            singleInvoice
        );
        uint256 poolCreationGas = gasSnapshot - gasleft();
        console2.log("Pool creation gas:", poolCreationGas);

        // Investment gas
        gasSnapshot = gasleft();
        vm.prank(investor1);
        fundingManager.investInPool(poolId, SMALL_INVESTMENT);
        uint256 investmentGas = gasSnapshot - gasleft();
        console2.log("Investment gas:", investmentGas);

        // Payment confirmation gas
        vm.prank(admin);
        fundingManager.allocateFundsToInvoices(poolId);
        
        vm.prank(exporter1);
        invoiceNft.withdrawFunds(invoiceId, SHIPPING_AMOUNT);

        gasSnapshot = gasleft();
        vm.prank(oracle1);
        paymentOracle.submitPaymentConfirmation(invoiceId, keccak256("gas_test_payment"), SHIPPING_AMOUNT);
        uint256 paymentGas = gasSnapshot - gasleft();
        console2.log("Payment confirmation gas:", paymentGas);

        // Settlement gas
        gasSnapshot = gasleft();
        vm.prank(admin);
        fundingManager.distributeProfits(poolId);
        uint256 settlementGas = gasSnapshot - gasleft();
        console2.log("Settlement gas:", settlementGas);

        uint256 totalGas = invoiceCreationGas + poolCreationGas + investmentGas + paymentGas + settlementGas;
        console2.log("Total lifecycle gas:", totalGas);
        
        // Verify gas usage is reasonable (under 2M gas for full lifecycle)
        assertLt(totalGas, 2_000_000, "Total gas should be under 2M");
        
        console2.log("=== Gas Optimization Analysis Complete ===");
    }

    // Helper Functions

    function _createTestInvoices(address exporter, uint256 count) internal returns (uint256[] memory) {
        uint256[] memory invoiceIds = new uint256[](count);
        
        vm.startPrank(exporter);
        for (uint256 i = 0; i < count; i++) {
            invoiceIds[i] = invoiceNft.mintInvoice(
                "Test Exporter Company",
                "Test Importer Company",
                INVOICE_AMOUNT + (i * 10_000e18), // Vary amounts slightly
                SHIPPING_AMOUNT + (i * 8_000e18),
                block.timestamp + 30 days + (i * 1 days)
            );
            // Finalize the invoice so it can be added to pools
            invoiceNft.finalizeInvoice(invoiceIds[i]);
        }
        vm.stopPrank();
        
        return invoiceIds;
    }

    function _createTestPool(string memory name, uint256[] memory invoiceIds) internal returns (uint256) {
        vm.prank(admin);
        return poolNft.createPool(name, invoiceIds);
    }

    function _performInvestments(uint256 poolId) internal returns (uint256) {
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        uint256 totalNeeded = pool.totalLoanAmount;
        uint256 totalInvested = 0;

        // Distribute investments across multiple investors
        uint256 investor1Share = totalNeeded * 50 / 100;
        uint256 investor2Share = totalNeeded * 30 / 100;
        uint256 investor3Share = totalNeeded - investor1Share - investor2Share;

        vm.prank(investor1);
        fundingManager.investInPool(poolId, investor1Share);
        totalInvested += investor1Share;

        vm.prank(investor2);
        fundingManager.investInPool(poolId, investor2Share);
        totalInvested += investor2Share;

        vm.prank(investor3);
        fundingManager.investInPool(poolId, investor3Share);
        totalInvested += investor3Share;

        return totalInvested;
    }

    function _performExporterWithdrawals(address exporter, uint256[] memory invoiceIds) internal {
        vm.startPrank(exporter);
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceIds[i]);
            invoiceNft.withdrawFunds(invoiceIds[i], invoice.shippingAmount);
        }
        vm.stopPrank();
    }

    function _performPaymentConfirmations(uint256[] memory invoiceIds) internal {
        vm.startPrank(oracle1);
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceIds[i]);
            bytes32 paymentHash = keccak256(abi.encodePacked("payment", i, block.timestamp));
            paymentOracle.submitPaymentConfirmation(invoiceIds[i], paymentHash, invoice.shippingAmount);
        }
        vm.stopPrank();
    }

    function _validateAnalyticsData(uint256 poolId, uint256 expectedInvestment) internal {
        // Test platform metrics
        PlatformAnalytics.PlatformMetrics memory metrics = analytics.getPlatformMetrics();
        
        assertGt(metrics.totalValueLocked, 0, "TVL should be greater than 0");
        assertGt(metrics.activePools, 0, "Should have active pools");
        assertGt(metrics.totalInvoicesCreated, 0, "Should have total invoices created");
        // Note: completedInvoices isn't directly available in metrics struct

        // Test pool performance
        vm.prank(admin);
        analytics.updatePoolPerformance(poolId);

        // Test investor portfolio  
        vm.prank(admin);
        analytics.updateInvestorPortfolio(investor1);

        console2.log("Analytics validation completed");
    }
}