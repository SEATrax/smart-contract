// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";

/**
 * @title Integration Test Suite
 * @notice Tests the integration between AccessControl, InvoiceNFT, and PoolNFT systems
 * @dev Verifies that role-based permissions work correctly across all contracts
 */
contract IntegrationTest is Test {
    // Test contracts
    PlatformAccessControl public accessControl;
    InvoiceNFT public invoiceNft;
    PoolNFT public poolNft;
    
    // Test addresses
    address public admin = makeAddr("admin");
    address public exporter1 = makeAddr("exporter1");
    address public exporter2 = makeAddr("exporter2");
    address public investor1 = makeAddr("investor1");
    address public investor2 = makeAddr("investor2");
    address public nonUser = makeAddr("nonUser");
    
    // Test constants
    uint256 constant SHIPPING_AMOUNT = 100000e18; // $100k
    uint256 constant LOAN_AMOUNT = 70000e18; // $70k
    uint256 constant SHIPPING_DATE = 1700000000;
    string constant EXPORTER_COMPANY = "Global Exports Ltd";
    string constant IMPORTER_COMPANY = "Import Solutions Inc";

    /**
     * @notice Set up the integration test environment
     */
    function setUp() public {
        // Deploy contracts with proper admin setup
        vm.startPrank(admin);
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        poolNft = new PoolNFT(address(accessControl), address(invoiceNft));
        
        // Setup comprehensive role structure
        accessControl.grantExporterRole(exporter1);
        accessControl.grantExporterRole(exporter2);
        accessControl.grantInvestorRole(investor1);
        accessControl.grantInvestorRole(investor2);
        
        vm.stopPrank();
    }

    // ================================
    // Complete Business Flow Integration Tests
    // ================================
    
    /**
     * @notice Test the complete invoice lifecycle with proper role-based access
     */
    function test_CompleteInvoiceLifecycle() public {
        console2.log("=== Testing Complete Invoice Lifecycle ===");
        
        // STEP 1: Exporter creates invoice
        console2.log("Step 1: Exporter creates invoice");
        vm.startPrank(exporter1);
        
        uint256 invoiceId = invoiceNft.mintInvoice(
            EXPORTER_COMPANY,
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        
        assertEq(invoiceId, 1);
        assertEq(invoiceNft.ownerOf(invoiceId), exporter1);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Pending));
        console2.log("[OK] Invoice created successfully");
        
        // STEP 2: Exporter finalizes invoice for funding
        console2.log("Step 2: Exporter finalizes invoice");
        invoiceNft.finalizeInvoice(invoiceId);
        
        invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Finalized));
        console2.log("[OK] Invoice finalized successfully");
        
        vm.stopPrank();
        
        // STEP 3: Admin (representing pool system) adds funding
        console2.log("Step 3: Admin adds funding from investor pools");
        vm.startPrank(admin);
        
        // First round of funding (50% of loan amount)
        uint256 firstFunding = (LOAN_AMOUNT * 5000) / 10000; // 50%
        invoiceNft.addFunding(invoiceId, firstFunding);
        
        invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Fundraising));
        assertEq(invoice.amountInvested, firstFunding);
        assertFalse(invoiceNft.isEligibleForWithdrawal(invoiceId)); // Below 70% threshold
        console2.log("[OK] First round of funding added (50%)");
        
        // Second round of funding (25% more, total 75%)
        uint256 secondFunding = (LOAN_AMOUNT * 2500) / 10000; // 25%
        invoiceNft.addFunding(invoiceId, secondFunding);
        
        invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
        assertEq(invoice.amountInvested, firstFunding + secondFunding);
        assertTrue(invoiceNft.isEligibleForWithdrawal(invoiceId)); // Above 70% threshold
        console2.log("[OK] Second round of funding added (75% total)");
        
        vm.stopPrank();
        
        // STEP 4: Exporter withdraws available funds
        console2.log("Step 4: Exporter withdraws available funds");
        vm.startPrank(exporter1);
        
        uint256 availableBefore = invoiceNft.getAvailableWithdrawal(invoiceId);
        assertEq(availableBefore, firstFunding + secondFunding);
        
        // Withdraw 50% of available amount
        uint256 withdrawAmount = availableBefore / 2;
        invoiceNft.withdrawFunds(invoiceId, withdrawAmount);
        
        invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(invoice.amountWithdrawn, withdrawAmount);
        assertEq(invoiceNft.getAvailableWithdrawal(invoiceId), availableBefore - withdrawAmount);
        console2.log("[OK] Partial withdrawal completed");
        
        vm.stopPrank();
        
        // STEP 5: Admin confirms payment from importer
        console2.log("Step 5: Admin confirms payment from importer");
        vm.startPrank(admin);
        
        invoiceNft.confirmPayment(invoiceId);
        
        invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
        console2.log("[OK] Payment confirmed successfully");
        
        vm.stopPrank();
        
        // STEP 6: Verify final platform statistics
        console2.log("Step 6: Verify platform statistics");
        (uint256 totalInvoices, uint256 totalLoan, uint256 totalInvested) = invoiceNft.getPlatformStats();
        assertEq(totalInvoices, 1);
        assertEq(totalLoan, LOAN_AMOUNT);
        assertEq(totalInvested, firstFunding + secondFunding);
        console2.log("[OK] Platform statistics verified");
        
        console2.log("=== Complete Invoice Lifecycle Test Passed ===");
    }
    
    /**
     * @notice Test role-based access controls across all operations
     */
    function test_RoleBasedAccessControls() public {
        console2.log("=== Testing Role-Based Access Controls ===");
        
        // Create invoice as exporter1
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            EXPORTER_COMPANY,
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Test unauthorized minting
        vm.startPrank(nonUser);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotExporter.selector, nonUser));
        invoiceNft.mintInvoice(
            "Unauthorized Company",
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        vm.stopPrank();
        console2.log("[OK] Unauthorized minting correctly blocked");
        
        // Test unauthorized funding
        vm.startPrank(investor1);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAdmin.selector, investor1));
        invoiceNft.addFunding(invoiceId, 10000e18);
        vm.stopPrank();
        console2.log("[OK] Unauthorized funding correctly blocked");
        
        // Test unauthorized payment confirmation
        vm.startPrank(exporter1);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAdmin.selector, exporter1));
        invoiceNft.confirmPayment(invoiceId);
        vm.stopPrank();
        console2.log("[OK] Unauthorized payment confirmation correctly blocked");
        
        // Test cross-exporter access (exporter2 trying to modify exporter1's invoice)
        vm.startPrank(exporter2);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAuthorized.selector, exporter2));
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        console2.log("[OK] Cross-exporter access correctly blocked");
        
        console2.log("=== Role-Based Access Controls Test Passed ===");
    }
    
    /**
     * @notice Test multi-exporter scenario with proper isolation
     */
    function test_MultiExporterScenario() public {
        console2.log("=== Testing Multi-Exporter Scenario ===");
        
        // EXPORTER 1: Create and finalize invoice
        vm.startPrank(exporter1);
        uint256 invoice1 = invoiceNft.mintInvoice(
            "Exporter 1 Corp",
            "Importer A Ltd",
            80000e18, // $80k
            50000e18, // $50k
            SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoice1);
        vm.stopPrank();
        
        // EXPORTER 2: Create and finalize different invoice
        vm.startPrank(exporter2);
        uint256 invoice2 = invoiceNft.mintInvoice(
            "Exporter 2 LLC",
            "Importer B Inc",
            120000e18, // $120k
            90000e18, // $90k
            SHIPPING_DATE + 1000
        );
        invoiceNft.finalizeInvoice(invoice2);
        vm.stopPrank();
        
        // Verify invoice ownership and isolation
        assertEq(invoiceNft.ownerOf(invoice1), exporter1);
        assertEq(invoiceNft.ownerOf(invoice2), exporter2);
        
        // Check each exporter can only see their own invoices
        uint256[] memory exp1Invoices = invoiceNft.getInvoicesByExporter(exporter1);
        uint256[] memory exp2Invoices = invoiceNft.getInvoicesByExporter(exporter2);
        
        assertEq(exp1Invoices.length, 1);
        assertEq(exp1Invoices[0], invoice1);
        assertEq(exp2Invoices.length, 1);
        assertEq(exp2Invoices[0], invoice2);
        console2.log("[OK] Invoice ownership and isolation verified");
        
        // Admin funds both invoices
        vm.startPrank(admin);
        invoiceNft.addFunding(invoice1, 35000e18); // 70% of 50k
        invoiceNft.addFunding(invoice2, 63000e18); // 70% of 90k
        vm.stopPrank();
        
        // Both exporters can withdraw their own funds
        vm.startPrank(exporter1);
        invoiceNft.withdrawFunds(invoice1, 20000e18);
        vm.stopPrank();
        
        vm.startPrank(exporter2);
        invoiceNft.withdrawFunds(invoice2, 30000e18);
        vm.stopPrank();
        
        // Verify correct withdrawal amounts
        InvoiceNFT.Invoice memory inv1 = invoiceNft.getInvoice(invoice1);
        InvoiceNFT.Invoice memory inv2 = invoiceNft.getInvoice(invoice2);
        
        assertEq(inv1.amountWithdrawn, 20000e18);
        assertEq(inv2.amountWithdrawn, 30000e18);
        console2.log("[OK] Independent withdrawals completed successfully");
        
        // Verify platform totals are correct
        (uint256 totalInvoices, uint256 totalLoan, uint256 totalInvested) = invoiceNft.getPlatformStats();
        assertEq(totalInvoices, 2);
        assertEq(totalLoan, 50000e18 + 90000e18); // Sum of both loan amounts
        assertEq(totalInvested, 35000e18 + 63000e18); // Sum of both investments
        console2.log("[OK] Platform totals correctly aggregated");
        
        console2.log("=== Multi-Exporter Scenario Test Passed ===");
    }
    
    /**
     * @notice Test role transitions and their effects
     */
    function test_RoleTransitionsAndEffects() public {
        console2.log("=== Testing Role Transitions and Effects ===");
        
        // Initially, non-user cannot mint invoices
        vm.startPrank(nonUser);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotExporter.selector, nonUser));
        invoiceNft.mintInvoice(
            EXPORTER_COMPANY,
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        vm.stopPrank();
        console2.log("[OK] Non-user correctly blocked from minting");
        
        // Admin grants exporter role to non-user
        vm.startPrank(admin);
        accessControl.grantExporterRole(nonUser);
        vm.stopPrank();
        
        // Now the user can mint invoices
        vm.startPrank(nonUser);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "New Exporter Company",
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        assertEq(invoiceNft.ownerOf(invoiceId), nonUser);
        console2.log("[OK] Newly granted exporter can mint invoices");
        vm.stopPrank();
        
        // Admin revokes exporter role
        vm.startPrank(admin);
        accessControl.revokeExporterRole(nonUser);
        vm.stopPrank();
        
        // User can no longer mint new invoices
        vm.startPrank(nonUser);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotExporter.selector, nonUser));
        invoiceNft.mintInvoice(
            "Another Company",
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        
        // But can still manage existing invoice (ownership remains)
        invoiceNft.finalizeInvoice(invoiceId);
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Finalized));
        console2.log("[OK] Revoked exporter blocked from new minting but retains existing ownership");
        
        vm.stopPrank();
        
        console2.log("=== Role Transitions and Effects Test Passed ===");
    }
    
    /**
     * @notice Test administrative operations integration
     */
    function test_AdministrativeOperationsIntegration() public {
        console2.log("=== Testing Administrative Operations Integration ===");
        
        // Create and finalize invoice
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            EXPORTER_COMPANY,
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Test admin can perform funding operations
        vm.startPrank(admin);
        invoiceNft.addFunding(invoiceId, LOAN_AMOUNT);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
        console2.log("[OK] Admin funding operations working");
        
        // Test admin can confirm payments
        invoiceNft.confirmPayment(invoiceId);
        invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
        console2.log("[OK] Admin payment confirmation working");
        
        vm.stopPrank();
        
        // Test that admin role management affects invoice operations
        address newAdmin = makeAddr("newAdmin");
        vm.startPrank(admin);
        accessControl.grantAdminRole(newAdmin);
        vm.stopPrank();
        
        // Create another invoice for testing
        vm.startPrank(exporter1);
        uint256 invoice2 = invoiceNft.mintInvoice(
            "Second Invoice",
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE + 1000
        );
        invoiceNft.finalizeInvoice(invoice2);
        vm.stopPrank();
        
        // New admin can also perform operations
        vm.startPrank(newAdmin);
        invoiceNft.addFunding(invoice2, 30000e18);
        
        invoice = invoiceNft.getInvoice(invoice2);
        assertTrue(invoice.amountInvested > 0);
        console2.log("[OK] New admin can perform invoice operations");
        
        vm.stopPrank();
        
        console2.log("=== Administrative Operations Integration Test Passed ===");
    }

    // ================================
    // Gas Optimization Integration Tests
    // ================================
    
    /**
     * @notice Test gas efficiency across integrated operations
     */
    function test_IntegratedGasEfficiency() public {
        console2.log("=== Testing Integrated Gas Efficiency ===");
        
        // Measure gas for complete workflow
        uint256 gasBefore = gasleft();
        
        // Complete workflow
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            EXPORTER_COMPANY,
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        invoiceNft.addFunding(invoiceId, LOAN_AMOUNT);
        invoiceNft.confirmPayment(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(exporter1);
        // Check if eligible and get available withdrawal amount
        if (invoiceNft.isEligibleForWithdrawal(invoiceId)) {
            uint256 availableAmount = invoiceNft.getAvailableWithdrawal(invoiceId);
            invoiceNft.withdrawFunds(invoiceId, availableAmount / 2); // Withdraw half of available
        }
        vm.stopPrank();
        
        uint256 totalGasUsed = gasBefore - gasleft();
        
        console2.log("Total gas for complete workflow:", totalGasUsed);
        console2.log("Average gas per operation:", totalGasUsed / 5);
        
        // Verify reasonable gas usage for complete workflow
        assertTrue(totalGasUsed < 1500000, "Complete workflow should use less than 1.5M gas");
        
        console2.log("=== Integrated Gas Efficiency Test Passed ===");
    }

    // ================================
    // Pool Integration Tests (Phase 4)
    // ================================
    
    /**
     * @notice Test complete pool lifecycle with invoice integration
     */
    function test_CompletePoolLifecycleIntegration() public {
        console2.log("=== Testing Complete Pool Lifecycle Integration ===");
        
        // STEP 1: Create multiple invoices
        console2.log("Step 1: Create multiple invoices");
        uint256[] memory invoiceIds = new uint256[](3);
        
        vm.startPrank(exporter1);
        invoiceIds[0] = invoiceNft.mintInvoice(
            "Exporter 1 Corp",
            "Importer A Inc",
            100000e18, // $100k
            70000e18,  // $70k
            SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceIds[0]);
        
        invoiceIds[1] = invoiceNft.mintInvoice(
            "Exporter 1 Corp",
            "Importer B Inc", 
            80000e18,  // $80k
            50000e18,  // $50k
            SHIPPING_DATE + 1000
        );
        invoiceNft.finalizeInvoice(invoiceIds[1]);
        vm.stopPrank();
        
        vm.startPrank(exporter2);
        invoiceIds[2] = invoiceNft.mintInvoice(
            "Exporter 2 LLC",
            "Importer C Ltd",
            120000e18, // $120k
            90000e18,  // $90k
            SHIPPING_DATE + 2000
        );
        invoiceNft.finalizeInvoice(invoiceIds[2]);
        vm.stopPrank();
        
        console2.log("[OK] Multiple invoices created and finalized");
        
        // STEP 2: Admin creates investment pool
        console2.log("Step 2: Admin creates investment pool");
        vm.startPrank(admin);
        
        uint256 poolId = poolNft.createPool("Q4 2024 Shipping Pool", invoiceIds);
        
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        assertEq(pool.invoiceCount, 3);
        assertEq(pool.totalLoanAmount, 70000e18 + 50000e18 + 90000e18); // $210k total
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Open));
        console2.log("[OK] Pool created with 3 invoices");
        
        // STEP 3: Finalize pool for fundraising
        console2.log("Step 3: Finalize pool for fundraising");
        poolNft.finalizePool(poolId);
        
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Fundraising));
        assertTrue(poolNft.isPoolEligibleForFunding(poolId));
        console2.log("[OK] Pool finalized and ready for funding");
        
        // STEP 4: Mark pool as funded (simulate investor funding)
        console2.log("Step 4: Mark pool as funded");
        uint256 totalLoanAmount = 210000e18; // $210k
        uint256 fundedAmount = (totalLoanAmount * 8500) / 10000; // 85% funding
        
        poolNft.markPoolFunded(poolId, fundedAmount);
        
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Funded));
        assertEq(pool.totalInvested, fundedAmount);
        console2.log("[OK] Pool marked as funded with 85% of loan amount");
        
        // STEP 5: Allocate pool funds to individual invoices
        console2.log("Step 5: Allocate pool funds to invoices");
        
        // Proportional allocation based on loan amounts
        uint256 allocation1 = (fundedAmount * 70000e18) / totalLoanAmount; // ~$59.5k
        uint256 allocation2 = (fundedAmount * 50000e18) / totalLoanAmount; // ~$42.5k  
        uint256 allocation3 = (fundedAmount * 90000e18) / totalLoanAmount; // ~$76.5k
        
        invoiceNft.addFunding(invoiceIds[0], allocation1);
        invoiceNft.addFunding(invoiceIds[1], allocation2);
        invoiceNft.addFunding(invoiceIds[2], allocation3);
        
        // Verify all invoices are now funded
        for (uint256 i = 0; i < 3; i++) {
            InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceIds[i]);
            assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
            assertTrue(invoiceNft.isEligibleForWithdrawal(invoiceIds[i]));
        }
        console2.log("[OK] Pool funds allocated to all invoices");
        
        // STEP 6: Exporters withdraw available funds
        console2.log("Step 6: Exporters withdraw funds");
        vm.stopPrank();
        
        vm.startPrank(exporter1);
        invoiceNft.withdrawFunds(invoiceIds[0], allocation1 / 2); // Partial withdrawal
        invoiceNft.withdrawFunds(invoiceIds[1], allocation2);     // Full withdrawal
        vm.stopPrank();
        
        vm.startPrank(exporter2); 
        invoiceNft.withdrawFunds(invoiceIds[2], allocation3 * 3 / 4); // 75% withdrawal
        vm.stopPrank();
        
        console2.log("[OK] Exporters withdrew available funds");
        
        // STEP 7: Mark all invoices as paid
        console2.log("Step 7: Mark invoices as paid");
        vm.startPrank(admin);
        
        for (uint256 i = 0; i < 3; i++) {
            invoiceNft.confirmPayment(invoiceIds[i]);
            InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceIds[i]);
            assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
        }
        console2.log("[OK] All invoices marked as paid");
        
        // STEP 8: Settle pool
        console2.log("Step 8: Settle pool");
        poolNft.markPoolSettling(poolId);
        
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Settling));
        console2.log("[OK] Pool marked as settling");
        
        // STEP 9: Complete pool with profit distribution
        console2.log("Step 9: Complete pool distribution");
        uint256 totalDistributed = fundedAmount + 10000e18; // Principal + $10k profit
        poolNft.markPoolCompleted(poolId, totalDistributed);
        
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Completed));
        assertEq(pool.totalDistributed, totalDistributed);
        console2.log("[OK] Pool completed with profit distribution");
        
        vm.stopPrank();
        
        console2.log("=== Complete Pool Lifecycle Integration Test Passed ===");
    }
    
    /**
     * @notice Test pool and invoice relationship validation
     */
    function test_PoolInvoiceRelationshipIntegration() public {
        console2.log("=== Testing Pool-Invoice Relationship Integration ===");
        
        // Create invoices
        vm.startPrank(exporter1);
        uint256 invoice1 = invoiceNft.mintInvoice(
            EXPORTER_COMPANY,
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoice1);
        
        uint256 invoice2 = invoiceNft.mintInvoice(
            "Another Company",
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE + 1000
        );
        invoiceNft.finalizeInvoice(invoice2);
        vm.stopPrank();
        
        // Create pool with one invoice
        vm.startPrank(admin);
        uint256[] memory poolInvoices1 = new uint256[](1);
        poolInvoices1[0] = invoice1;
        uint256 pool1 = poolNft.createPool("Pool 1", poolInvoices1);
        
        // Verify invoice is associated with pool
        assertEq(poolNft.getInvoicePool(invoice1), pool1);
        assertEq(poolNft.getInvoicePool(invoice2), 0); // Not in any pool
        console2.log("[OK] Invoice-pool relationships correctly established");
        
        // Try to create another pool with same invoice (should fail)
        uint256[] memory duplicateInvoices = new uint256[](1);
        duplicateInvoices[0] = invoice1;
        
        vm.expectRevert(abi.encodeWithSelector(
            PoolNFT.InvoiceAlreadyInPool.selector,
            invoice1,
            pool1
        ));
        poolNft.createPool("Pool 2", duplicateInvoices);
        console2.log("[OK] Duplicate invoice in pool correctly blocked");
        
        // Create second pool with different invoice
        uint256[] memory poolInvoices2 = new uint256[](1);
        poolInvoices2[0] = invoice2;
        uint256 pool2 = poolNft.createPool("Pool 2", poolInvoices2);
        
        // Verify segregation
        assertEq(poolNft.getInvoicePool(invoice1), pool1);
        assertEq(poolNft.getInvoicePool(invoice2), pool2);
        console2.log("[OK] Multiple pools with different invoices working correctly");
        
        vm.stopPrank();
        
        console2.log("=== Pool-Invoice Relationship Integration Test Passed ===");
    }
    
    /**
     * @notice Test pool access control integration
     */
    function test_PoolAccessControlIntegration() public {
        console2.log("=== Testing Pool Access Control Integration ===");
        
        // Create invoice for pool testing
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            EXPORTER_COMPANY,
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Test non-admin cannot create pools
        vm.startPrank(exporter1);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        
        vm.expectRevert(abi.encodeWithSelector(PoolNFT.NotAdmin.selector, exporter1));
        poolNft.createPool("Unauthorized Pool", invoiceIds);
        vm.stopPrank();
        console2.log("[OK] Non-admin blocked from pool creation");
        
        // Test admin can create pools
        vm.startPrank(admin);
        uint256 poolId = poolNft.createPool("Admin Pool", invoiceIds);
        assertEq(poolNft.ownerOf(poolId), admin);
        console2.log("[OK] Admin successfully created pool");
        
        // Test non-admin cannot finalize pools
        vm.stopPrank();
        vm.startPrank(exporter1);
        vm.expectRevert(abi.encodeWithSelector(PoolNFT.NotAdmin.selector, exporter1));
        poolNft.finalizePool(poolId);
        vm.stopPrank();
        console2.log("[OK] Non-admin blocked from pool finalization");
        
        // Test admin can finalize pools
        vm.startPrank(admin);
        poolNft.finalizePool(poolId);
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Fundraising));
        console2.log("[OK] Admin successfully finalized pool");
        
        // Test role transitions affect pool operations
        address newAdmin = makeAddr("newAdmin");
        accessControl.grantAdminRole(newAdmin);
        vm.stopPrank();
        
        // New admin can also perform pool operations
        vm.startPrank(newAdmin);
        poolNft.markPoolFunded(poolId, LOAN_AMOUNT);
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Funded));
        console2.log("[OK] New admin can perform pool operations");
        
        vm.stopPrank();
        
        console2.log("=== Pool Access Control Integration Test Passed ===");
    }
    
    /**
     * @notice Test pool validation with invoice states
     */
    function test_PoolInvoiceStateValidation() public {
        console2.log("=== Testing Pool-Invoice State Validation ===");
        
        // Create invoices with different states
        vm.startPrank(exporter1);
        
        // Pending invoice (not finalized)
        uint256 pendingInvoice = invoiceNft.mintInvoice(
            "Pending Corp",
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE
        );
        // Don't finalize
        
        // Finalized invoice
        uint256 finalizedInvoice = invoiceNft.mintInvoice(
            "Finalized Corp", 
            IMPORTER_COMPANY,
            SHIPPING_AMOUNT,
            LOAN_AMOUNT,
            SHIPPING_DATE + 1000
        );
        invoiceNft.finalizeInvoice(finalizedInvoice);
        vm.stopPrank();
        
        // Try to create pool with pending invoice (should fail)
        vm.startPrank(admin);
        uint256[] memory pendingInvoices = new uint256[](1);
        pendingInvoices[0] = pendingInvoice;
        
        vm.expectRevert(abi.encodeWithSelector(
            PoolNFT.InvoiceNotFinalized.selector,
            pendingInvoice
        ));
        poolNft.createPool("Invalid Pool", pendingInvoices);
        console2.log("[OK] Pool creation blocked for pending invoices");
        
        // Create pool with finalized invoice (should succeed)
        uint256[] memory finalizedInvoices = new uint256[](1);
        finalizedInvoices[0] = finalizedInvoice;
        uint256 poolId = poolNft.createPool("Valid Pool", finalizedInvoices);
        
        assertTrue(poolNft.validatePoolForFunding(poolId) == false); // Not yet fundraising
        poolNft.finalizePool(poolId);
        assertTrue(poolNft.validatePoolForFunding(poolId)); // Now valid
        console2.log("[OK] Pool validation correctly checks invoice states");
        
        // Fund the invoice, which should invalidate pool for new funding
        invoiceNft.addFunding(finalizedInvoice, LOAN_AMOUNT);
        assertFalse(poolNft.validatePoolForFunding(poolId));
        console2.log("[OK] Pool validation correctly detects funded invoices");
        
        vm.stopPrank();
        
        console2.log("=== Pool-Invoice State Validation Test Passed ===");
    }
}