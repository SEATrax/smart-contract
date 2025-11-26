// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";

/**
 * @title Integration Test Suite
 * @notice Tests the integration between AccessControl and InvoiceNFT systems
 * @dev Verifies that role-based permissions work correctly across all contracts
 */
contract IntegrationTest is Test {
    // Test contracts
    PlatformAccessControl public accessControl;
    InvoiceNFT public invoiceNft;
    
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
        invoiceNft.withdrawFunds(invoiceId, LOAN_AMOUNT / 2);
        vm.stopPrank();
        
        uint256 totalGasUsed = gasBefore - gasleft();
        
        console2.log("Total gas for complete workflow:", totalGasUsed);
        console2.log("Average gas per operation:", totalGasUsed / 5);
        
        // Verify reasonable gas usage for complete workflow
        assertTrue(totalGasUsed < 1500000, "Complete workflow should use less than 1.5M gas");
        
        console2.log("=== Integrated Gas Efficiency Test Passed ===");
    }
}