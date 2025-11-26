// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {PlatformAnalytics} from "../src/PlatformAnalytics.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";
import {PaymentOracle} from "../src/PaymentOracle.sol";

/**
 * @title Phase7AnalyticsSimpleTest
 * @notice Simplified analytics integration test without Unicode characters
 */
contract Phase7AnalyticsSimpleTest is Test {
    PlatformAnalytics public analytics;
    PlatformAccessControl public accessControl;
    InvoiceNFT public invoiceNFT;
    PoolNFT public poolNFT;
    PoolFundingManager public fundingManager;
    PaymentOracle public paymentOracle;

    address public admin = makeAddr("admin");
    address public oracle1 = makeAddr("oracle1");
    address public oracle2 = makeAddr("oracle2");
    address public investor1 = makeAddr("investor1");
    address public investor2 = makeAddr("investor2");
    address public exporter1 = makeAddr("exporter1");
    address public buyer1 = makeAddr("buyer1");

    uint256 public constant INVESTMENT_AMOUNT = 100000e6;
    uint256 public constant INVOICE_AMOUNT = 200000e6;

    function setUp() public {
        accessControl = new PlatformAccessControl(admin);

        vm.startPrank(admin);
        invoiceNFT = new InvoiceNFT(address(accessControl));
        poolNFT = new PoolNFT(address(accessControl), address(invoiceNFT));
        fundingManager = new PoolFundingManager(
            address(accessControl),
            address(invoiceNFT),
            address(poolNFT)
        );
        paymentOracle = new PaymentOracle(
            address(accessControl),
            address(invoiceNFT),
            address(poolNFT),
            address(fundingManager)
        );
        analytics = new PlatformAnalytics(
            address(accessControl),
            address(invoiceNFT),
            address(poolNFT),
            address(fundingManager),
            address(paymentOracle)
        );

        accessControl.grantAdminRole(address(analytics));
        accessControl.grantAdminRole(address(fundingManager));
        accessControl.grantAdminRole(address(paymentOracle));

        paymentOracle.authorizeOracle(oracle1);
        paymentOracle.authorizeOracle(oracle2);
        vm.stopPrank();
    }

    function testBasicAnalyticsWorkflow() public {
        console2.log("=== Basic Analytics Workflow Test ===");
        
        // Create test data
        uint256 poolId = _createTestPool();
        
        // Make investments
        vm.prank(investor1);
        fundingManager.investInPool(poolId, INVESTMENT_AMOUNT);
        
        vm.prank(investor2);
        fundingManager.investInPool(poolId, INVESTMENT_AMOUNT * 2);
        
        // Update analytics
        vm.prank(admin);
        analytics.updatePlatformMetrics();
        
        analytics.updateInvestorPortfolio(investor1);
        analytics.updateInvestorPortfolio(investor2);
        analytics.updatePoolPerformance(poolId);
        analytics.updateExporterMetrics(exporter1);
        
        // Verify results
        PlatformAnalytics.PlatformMetrics memory platformMetrics = analytics.getPlatformMetrics();
        assertEq(platformMetrics.totalPoolsCreated, 1);
        assertEq(platformMetrics.totalInvoicesCreated, 3);
        
        PlatformAnalytics.InvestorPortfolio memory portfolio1 = analytics.getInvestorPortfolio(investor1);
        assertEq(portfolio1.totalInvested, INVESTMENT_AMOUNT);
        
        PlatformAnalytics.InvestorPortfolio memory portfolio2 = analytics.getInvestorPortfolio(investor2);
        assertEq(portfolio2.totalInvested, INVESTMENT_AMOUNT * 2);
        
        PlatformAnalytics.PoolPerformance memory poolPerf = analytics.getPoolPerformance(poolId);
        assertEq(poolPerf.totalFunded, INVESTMENT_AMOUNT * 3);
        
        console2.log("Basic analytics workflow completed successfully");
    }

    function testAnalyticsReporting() public {
        console2.log("=== Analytics Reporting Test ===");
        
        // Setup test scenario
        uint256 pool1 = _createTestPool();
        uint256 pool2 = _createTestPool();
        
        vm.prank(investor1);
        fundingManager.investInPool(pool1, INVESTMENT_AMOUNT);
        
        vm.prank(investor2);
        fundingManager.investInPool(pool2, INVESTMENT_AMOUNT);
        
        // Update all metrics
        vm.prank(admin);
        analytics.updatePlatformMetrics();
        analytics.updateInvestorPortfolio(investor1);
        analytics.updateInvestorPortfolio(investor2);
        analytics.updatePoolPerformance(pool1);
        analytics.updatePoolPerformance(pool2);
        
        // Test portfolio breakdown
        (
            uint256[] memory poolIds,
            uint256[] memory investments,
            uint256[] memory investorReturns,
            uint256[] memory rois
        ) = analytics.getInvestorPoolBreakdown(investor1);
        
        assertEq(poolIds.length, 1);
        assertEq(investments[0], INVESTMENT_AMOUNT);
        
        // Test risk assessment
        (uint256 riskScore, uint256[] memory riskFactors, string[] memory descriptions) = 
            analytics.getPoolRiskAssessment(pool1);
        
        assertGt(riskScore, 0);
        assertEq(riskFactors.length, 5);
        assertEq(descriptions.length, 5);
        
        console2.log("Analytics reporting test completed successfully");
    }

    function testHistoricalTracking() public {
        console2.log("=== Historical Tracking Test ===");
        
        // Create initial data
        uint256 poolId = _createTestPool();
        
        vm.prank(admin);
        analytics.createHistoricalSnapshot();
        
        // Add investment and advance time
        vm.prank(investor1);
        fundingManager.investInPool(poolId, INVESTMENT_AMOUNT);
        
        vm.warp(block.timestamp + 1 days);
        
        vm.prank(admin);
        analytics.createHistoricalSnapshot();
        
        // Test historical trends
        uint256 fromTime = block.timestamp - 2 days;
        uint256 toTime = block.timestamp;
        
        (
            uint256[] memory timestamps,
            uint256[] memory volumes,
            uint256[] memory rois
        ) = analytics.getHistoricalTrends(fromTime, toTime);
        
        assertGt(timestamps.length, 0);
        
        console2.log("Historical tracking test completed successfully");
    }

    function testErrorHandling() public {
        console2.log("=== Error Handling Test ===");
        
        // Test zero address
        vm.expectRevert(PlatformAnalytics.ZeroAddress.selector);
        analytics.updateInvestorPortfolio(address(0));
        
        // Test invalid pool ID
        vm.expectRevert(abi.encodeWithSelector(PlatformAnalytics.InvalidPoolId.selector, 999));
        analytics.updatePoolPerformance(999);
        
        // Test non-admin access
        vm.expectRevert(abi.encodeWithSelector(PlatformAnalytics.NotAdmin.selector, investor1));
        vm.prank(investor1);
        analytics.updatePlatformMetrics();
        
        console2.log("Error handling test completed successfully");
    }

    function _createTestPool() internal returns (uint256) {
        uint256[] memory invoiceIds = new uint256[](3);
        
        vm.startPrank(admin);
        for (uint256 i = 0; i < 3; i++) {
            invoiceNFT.mintInvoice(
                "Test Exporter Company",
                "Test Importer Company",
                INVOICE_AMOUNT,
                INVOICE_AMOUNT * 80 / 100, // 80% loan amount
                block.timestamp + 30 days
            );
            invoiceIds[i] = i + 1;
        }
        vm.stopPrank();
        
        vm.prank(exporter1);
        uint256 poolId = poolNFT.createPool(
            "Test Pool",
            invoiceIds
        );
        
        return poolId;
    }
}