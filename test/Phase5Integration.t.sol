// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";

import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";

/**
 * @title Phase5Integration
 * @notice Integration test for Phase 5 Pool Funding Manager functionality
 */
contract Phase5Integration is Test {
    PlatformAccessControl internal accessControl;
    InvoiceNFT internal invoiceNft;
    PoolNFT internal poolNft;
    PoolFundingManager internal fundingManager;

    address internal admin = makeAddr("admin");
    address internal exporter = makeAddr("exporter");
    address internal investor = makeAddr("investor");

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        poolNft = new PoolNFT(address(accessControl), address(invoiceNft));
        fundingManager = new PoolFundingManager(
            address(accessControl),
            address(invoiceNft),
            address(poolNft)
        );
        
        accessControl.grantExporterRole(exporter);
        accessControl.grantInvestorRole(investor);
        vm.stopPrank();
    }

    function test_Phase5CoreFunctionality() public {
        console2.log("=== Phase 5 Core Functionality Test ===");
        
        // Step 1: Create invoice
        vm.startPrank(exporter);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Test Corp",
            "Import Inc",
            100000e18, // $100k
            70000e18,  // $70k
            block.timestamp + 86400
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        console2.log("[OK] Invoice created and finalized");
        
        // Step 2: Create pool
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Test Pool", invoiceIds);
        poolNft.finalizePool(poolId);
        vm.stopPrank();
        console2.log("[OK] Pool created and finalized");
        
        // Step 3: Investor invests in pool
        vm.startPrank(investor);
        uint256 investment = 50000e18; // $50k investment
        fundingManager.investInPool(poolId, investment);
        vm.stopPrank();
        
        // Verify investment recorded
        assertEq(fundingManager.investorPoolInvestments(poolId, investor), investment);
        assertEq(fundingManager.poolTotalInvestment(poolId), investment);
        console2.log("[OK] Investment recorded correctly");
        
        // Step 4: Check funding stats
        (uint256 totalInvested, uint256 investorCount, uint256 fundingProgress) = 
            fundingManager.getPoolFundingStats(poolId);
        
        assertEq(totalInvested, investment);
        assertEq(investorCount, 1);
        assertTrue(fundingProgress > 7000); // Should be over 70%
        console2.log("[OK] Funding statistics working");
        
        // Step 5: Check investor info
        (uint256 investmentAmount, bool canClaim, uint256 estimatedReturn) = 
            fundingManager.getInvestorPoolInfo(investor, poolId);
        
        assertEq(investmentAmount, investment);
        assertEq(canClaim, false); // Pool not completed yet
        assertEq(estimatedReturn, investment); // No rewards yet
        console2.log("[OK] Investor info working");
        
        // Step 6: Check platform stats
        (uint256 totalRevenue, uint256 totalReturns, uint256 poolsInvested) = 
            fundingManager.getPlatformStats();
        
        assertEq(totalRevenue, 0); // No profits distributed yet
        assertEq(totalReturns, 0);
        assertEq(poolsInvested, 1); // One pool has received investment
        console2.log("[OK] Platform statistics working");
        
        console2.log("=== Phase 5 Core Functionality Test Passed ===");
    }
    
    function test_Phase5InvestmentValidation() public {
        console2.log("=== Phase 5 Investment Validation Test ===");
        
        // Create basic setup
        vm.startPrank(exporter);
        uint256 invoiceId = invoiceNft.mintInvoice("Corp", "Import", 100000e18, 70000e18, block.timestamp + 86400);
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Test Pool", invoiceIds);
        poolNft.finalizePool(poolId);
        vm.stopPrank();
        
        // Test minimum investment requirement
        vm.startPrank(investor);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.InvestmentTooSmall.selector,
            500e18,
            1000e18
        ));
        fundingManager.investInPool(poolId, 500e18); // Below minimum
        
        // Test successful investment
        fundingManager.investInPool(poolId, 1500e18); // Above minimum
        vm.stopPrank();
        
        console2.log("[OK] Investment validation working");
        console2.log("=== Phase 5 Investment Validation Test Passed ===");
    }
    
    function test_Phase5AccessControl() public {
        console2.log("=== Phase 5 Access Control Test ===");
        
        // Create basic setup
        vm.startPrank(exporter);
        uint256 invoiceId = invoiceNft.mintInvoice("Corp", "Import", 100000e18, 70000e18, block.timestamp + 86400);
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Test Pool", invoiceIds);
        poolNft.finalizePool(poolId);
        vm.stopPrank();
        
        // Test non-investor cannot invest
        address nonInvestor = makeAddr("nonInvestor");
        vm.startPrank(nonInvestor);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.NotInvestor.selector,
            nonInvestor
        ));
        fundingManager.investInPool(poolId, 5000e18);
        vm.stopPrank();
        
        console2.log("[OK] Access control working");
        console2.log("=== Phase 5 Access Control Test Passed ===");
    }
}