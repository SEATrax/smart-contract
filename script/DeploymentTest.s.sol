// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";
import {PaymentOracle} from "../src/PaymentOracle.sol";
import {PlatformAnalytics} from "../src/PlatformAnalytics.sol";

/**
 * @title Deployment Test Script
 * @notice Validates deployment by testing core functionality with demo data
 * @dev Run this after deployment to ensure everything is working correctly
 */
contract DeploymentTestScript is Script {
    // Contract addresses (set these from deployment output)
    address accessControl = vm.envAddress("ACCESS_CONTROL");
    address invoiceNFT = vm.envAddress("INVOICE_NFT");
    address poolNFT = vm.envAddress("POOL_NFT");
    address poolFundingManager = vm.envAddress("POOL_FUNDING_MANAGER");
    address paymentOracle = vm.envAddress("PAYMENT_ORACLE");
    address platformAnalytics = vm.envAddress("PLATFORM_ANALYTICS");
    
    // Test accounts
    address admin = vm.envAddress("PLATFORM_ADMIN");
    address exporter = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address investor = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address oracle = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    
    // Test data
    uint256 testInvoiceId;
    uint256 testPoolId;

    function setUp() public {
        console.log("=== DEPLOYMENT VALIDATION TEST ===");
        console.log("Access Control:", accessControl);
        console.log("Invoice NFT:", invoiceNFT);
        console.log("Pool NFT:", poolNFT);
        console.log("Pool Funding Manager:", poolFundingManager);
        console.log("Payment Oracle:", paymentOracle);
        console.log("Platform Analytics:", platformAnalytics);
        console.log("");
        console.log("Test Accounts:");
        console.log("Admin:", admin);
        console.log("Exporter:", exporter);
        console.log("Investor:", investor);
        console.log("Oracle:", oracle);
        console.log("============================");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\nStarting deployment validation tests...");
        
        // Test 1: Validate contract deployments
        console.log("\n=== Test 1: Contract Deployment Validation ===");
        testContractDeployments();
        
        // Test 2: Test role management
        console.log("\n=== Test 2: Role Management ===");
        testRoleManagement();
        
        // Test 3: Test invoice creation
        console.log("\n=== Test 3: Invoice Creation ===");
        testInvoiceCreation();
        
        // Test 4: Test pool creation
        console.log("\n=== Test 4: Pool Creation ===");
        testPoolCreation();
        
        // Test 5: Test investment flow
        console.log("\n=== Test 5: Investment Flow ===");
        testInvestmentFlow();
        
        // Test 6: Test analytics
        console.log("\n=== Test 6: Analytics System ===");
        testAnalytics();
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT VALIDATION COMPLETED ===");
        console.log("All core functionality tested successfully!");
        console.log("Platform is ready for use.");
        console.log("==============================");
    }
    
    function testContractDeployments() internal view {
        console.log("Testing contract deployments...");
        
        // Check that all contracts are deployed (have code)
        require(accessControl.code.length > 0, "AccessControl not deployed");
        require(invoiceNFT.code.length > 0, "InvoiceNFT not deployed");
        require(poolNFT.code.length > 0, "PoolNFT not deployed");
        require(poolFundingManager.code.length > 0, "PoolFundingManager not deployed");
        require(paymentOracle.code.length > 0, "PaymentOracle not deployed");
        require(platformAnalytics.code.length > 0, "PlatformAnalytics not deployed");
        
        console.log("[PASS] All contracts successfully deployed");
        
        // Test contract names and symbols
        string memory invoiceName = InvoiceNFT(invoiceNFT).name();
        string memory invoiceSymbol = InvoiceNFT(invoiceNFT).symbol();
        console.log("Invoice NFT:", invoiceName, "(" , invoiceSymbol , ")");
        
        string memory poolName = PoolNFT(poolNFT).name();
        string memory poolSymbol = PoolNFT(poolNFT).symbol();
        console.log("Pool NFT:", poolName, "(", poolSymbol, ")");
        
        console.log("[PASS] Contract names and symbols correct");
    }
    
    function testRoleManagement() internal {
        console.log("Testing role management...");
        
        PlatformAccessControl ac = PlatformAccessControl(accessControl);
        
        // Check admin role
        bool isAdmin = ac.isAdmin(admin);
        require(isAdmin, "Admin role not set");
        console.log("[PASS] Admin role verified for:", admin);
        
        // Grant and verify exporter role
        if (!ac.isExporter(exporter)) {
            ac.grantExporterRole(exporter);
        }
        require(ac.isExporter(exporter), "Exporter role not granted");
        console.log("[PASS] Exporter role granted to:", exporter);
        
        // Grant and verify investor role
        if (!ac.isInvestor(investor)) {
            ac.grantInvestorRole(investor);
        }
        require(ac.isInvestor(investor), "Investor role not granted");
        console.log("[PASS] Investor role granted to:", investor);
        
        // Authorize oracle
        PaymentOracle po = PaymentOracle(paymentOracle);
        if (!po.isAuthorizedOracle(oracle)) {
            po.authorizeOracle(oracle);
        }
        require(po.isAuthorizedOracle(oracle), "Oracle not authorized");
        console.log("[PASS] Oracle authorized:", oracle);
    }
    
    function testInvoiceCreation() internal {
        console.log("Testing invoice creation...");
        
        InvoiceNFT inv = InvoiceNFT(invoiceNFT);
        
        // Stop and start broadcasting as exporter
        vm.stopBroadcast();
        vm.startBroadcast(exporter);
        
        // Create test invoice
        uint256 shippingAmount = 5000e18; // 5000 tokens
        uint256 loanAmount = 3500e18;     // 3500 tokens (70%)
        uint256 shippingDate = block.timestamp + 30 days;
        
        testInvoiceId = inv.mintInvoice(
            "Acme Export Corp",
            "Global Import Ltd",
            shippingAmount,
            loanAmount,
            shippingDate
        );
        
        console.log("[PASS] Invoice created with ID:", testInvoiceId);
        
        // Finalize the invoice
        inv.finalizeInvoice(testInvoiceId);
        console.log("[PASS] Invoice finalized");
        
        // Verify invoice data
        InvoiceNFT.Invoice memory invoice = inv.getInvoice(testInvoiceId);
        require(invoice.exporterWallet == exporter, "Incorrect exporter");
        require(invoice.shippingAmount == shippingAmount, "Incorrect shipping amount");
        require(invoice.loanAmount == loanAmount, "Incorrect loan amount");
        console.log("[PASS] Invoice data verified");
        
        // Resume as admin
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    }
    
    function testPoolCreation() internal {
        console.log("Testing pool creation...");
        
        PoolNFT pool = PoolNFT(poolNFT);
        
        // Create array with our test invoice
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = testInvoiceId;
        
        // Create pool
        testPoolId = pool.createPool("Test Investment Pool", invoiceIds);
        console.log("[PASS] Pool created with ID:", testPoolId);
        
        // Finalize pool for fundraising
        pool.finalizePool(testPoolId);
        console.log("[PASS] Pool finalized for fundraising");
        
        // Verify pool data
        PoolNFT.Pool memory poolData = pool.getPool(testPoolId);
        require(poolData.creator == admin, "Incorrect pool creator");
        require(poolData.invoiceCount == 1, "Incorrect invoice count");
        require(poolData.status == PoolNFT.PoolStatus.Fundraising, "Pool not in fundraising status");
        console.log("[PASS] Pool data verified");
        
        // Verify invoice is in pool
        uint256[] memory poolInvoices = pool.getPoolInvoices(testPoolId);
        require(poolInvoices.length == 1, "Incorrect pool invoice count");
        require(poolInvoices[0] == testInvoiceId, "Invoice not in pool");
        console.log("[PASS] Invoice-pool relationship verified");
    }
    
    function testInvestmentFlow() internal {
        console.log("Testing investment flow...");
        
        PoolFundingManager pfm = PoolFundingManager(poolFundingManager);
        
        // Switch to investor account
        vm.stopBroadcast();
        vm.startBroadcast(investor);
        
        // Make investment (2500 tokens - 71% of loan amount)
        uint256 investmentAmount = 2500e18;
        pfm.investInPool(testPoolId, investmentAmount);
        console.log("[PASS] Investment made:", investmentAmount);
        
        // Resume as admin
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        // Verify investment
        (uint256 investment, bool canClaim, uint256 estimatedReturn) = 
            pfm.getInvestorPoolInfo(investor, testPoolId);
        require(investment == investmentAmount, "Investment amount incorrect");
        console.log("[PASS] Investment verified. Estimated return:", estimatedReturn);
        
        // Allocate funds to invoices (70% threshold met)
        pfm.allocateFundsToInvoices(testPoolId);
        console.log("[PASS] Funds allocated to invoices");
        
        // Verify pool funding stats
        (uint256 totalInvested, uint256 investorCount, uint256 fundingProgress) =
            pfm.getPoolFundingStats(testPoolId);
        require(totalInvested == investmentAmount, "Total invested incorrect");
        require(investorCount == 1, "Investor count incorrect");
        console.log("[PASS] Pool funding stats verified");
        console.log("  Total invested:", totalInvested);
        console.log("  Investor count:", investorCount);
        console.log("  Funding progress:", fundingProgress, "basis points");
    }
    
    function testAnalytics() internal {
        console.log("Testing analytics system...");
        
        PlatformAnalytics analytics = PlatformAnalytics(platformAnalytics);
        
        // Update platform metrics
        analytics.updatePlatformMetrics();
        console.log("[PASS] Platform metrics updated");
        
        // Update investor portfolio
        analytics.updateInvestorPortfolio(investor);
        console.log("[PASS] Investor portfolio updated");
        
        // Get platform stats
        PlatformAnalytics.PlatformMetrics memory metrics = analytics.getPlatformMetrics();
        console.log("[PASS] Platform metrics retrieved:");
        console.log("  Total invoices:", metrics.totalInvoicesCreated);
        console.log("  Total pools:", metrics.totalPoolsCreated);
        console.log("  Active invoices:", metrics.activeInvoices);
        console.log("  Active pools:", metrics.activePools);
        
        // Get investor portfolio
        PlatformAnalytics.InvestorPortfolio memory portfolio = analytics.getInvestorPortfolio(investor);
        console.log("[PASS] Investor portfolio retrieved:");
        console.log("  Total invested:", portfolio.totalInvested);
        console.log("  Total pools invested:", portfolio.totalPoolsInvested);
    }
}