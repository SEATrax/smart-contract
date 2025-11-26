// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";

/**
 * @title PoolFundingManagerTest
 * @notice Comprehensive test suite for the Pool Funding Manager
 */
contract PoolFundingManagerTest is Test {
    // ================================
    // Test Contracts
    // ================================
    
    PlatformAccessControl internal accessControl;
    InvoiceNFT internal invoiceNft;
    PoolNFT internal poolNft;
    PoolFundingManager internal fundingManager;
    
    // ================================
    // Test Accounts
    // ================================
    
    address internal admin = makeAddr("admin");
    address internal exporter1 = makeAddr("exporter1");
    address internal exporter2 = makeAddr("exporter2");
    address internal investor1 = makeAddr("investor1");
    address internal investor2 = makeAddr("investor2");
    address internal investor3 = makeAddr("investor3");
    address internal nonUser = makeAddr("nonUser");
    
    // ================================
    // Test Constants
    // ================================
    
    string constant EXPORTER_COMPANY = "Test Exporter Corp";
    string constant IMPORTER_COMPANY = "Test Importer Inc";
    string constant POOL_NAME = "Q4 2024 Test Pool";
    
    uint256 constant SHIPPING_AMOUNT = 100000e18; // $100k
    uint256 constant LOAN_AMOUNT = 70000e18; // $70k
    uint256 constant SHIPPING_DATE = 1735689600; // Jan 1, 2025
    
    uint256 constant MIN_INVESTMENT = 1000e18; // $1k
    uint256 constant LARGE_INVESTMENT = 50000e18; // $50k
    
    // Test data
    uint256[] internal sampleInvoiceIds;
    uint256 internal samplePoolId;
    
    // ================================
    // Setup Functions
    // ================================
    
    function setUp() public {
        // Deploy contracts
        vm.startPrank(admin);
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        poolNft = new PoolNFT(address(accessControl), address(invoiceNft));
        fundingManager = new PoolFundingManager(
            address(accessControl),
            address(invoiceNft),
            address(poolNft)
        );
        
        // Setup roles
        accessControl.grantExporterRole(exporter1);
        accessControl.grantExporterRole(exporter2);
        accessControl.grantInvestorRole(investor1);
        accessControl.grantInvestorRole(investor2);
        accessControl.grantInvestorRole(investor3);
        // Grant admin role to PoolFundingManager contract so it can call admin functions
        accessControl.grantAdminRole(address(fundingManager));
        
        vm.stopPrank();
        
        // Create sample invoices and pool
        _createSampleData();
    }
    
    function _createSampleData() internal {
        // Create sample invoices
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
            "Another Corp",
            IMPORTER_COMPANY,
            80000e18,
            50000e18,
            SHIPPING_DATE + 1000
        );
        invoiceNft.finalizeInvoice(invoice2);
        vm.stopPrank();
        
        vm.startPrank(exporter2);
        uint256 invoice3 = invoiceNft.mintInvoice(
            "Third Corp",
            IMPORTER_COMPANY,
            60000e18,
            40000e18,
            SHIPPING_DATE + 2000
        );
        invoiceNft.finalizeInvoice(invoice3);
        vm.stopPrank();
        
        // Store invoice IDs
        sampleInvoiceIds = [invoice1, invoice2, invoice3];
        
        // Create sample pool
        vm.startPrank(admin);
        samplePoolId = poolNft.createPool(POOL_NAME, sampleInvoiceIds);
        poolNft.finalizePool(samplePoolId);
        vm.stopPrank();
    }
    
    // ================================
    // Constructor Tests
    // ================================
    
    function test_Constructor_Success() public view {
        assertEq(address(fundingManager.ACCESS_CONTROL()), address(accessControl));
        assertEq(address(fundingManager.INVOICE_NFT()), address(invoiceNft));
        assertEq(address(fundingManager.POOL_NFT()), address(poolNft));
        
        // Check constants
        assertEq(fundingManager.PLATFORM_FEE_RATE(), 100); // 1%
        assertEq(fundingManager.INVESTOR_YIELD_RATE(), 400); // 4%
        assertEq(fundingManager.BASIS_POINTS(), 10000);
        assertEq(fundingManager.MIN_INVESTMENT(), 1000e18);
        assertEq(fundingManager.MAX_INVESTMENT_PER_POOL(), 1000000e18);
    }
    
    function test_Constructor_RevertZeroAddressAccessControl() public {
        vm.expectRevert(PoolFundingManager.ZeroAddress.selector);
        new PoolFundingManager(address(0), address(invoiceNft), address(poolNft));
    }
    
    function test_Constructor_RevertZeroAddressInvoiceNft() public {
        vm.expectRevert(PoolFundingManager.ZeroAddress.selector);
        new PoolFundingManager(address(accessControl), address(0), address(poolNft));
    }
    
    function test_Constructor_RevertZeroAddressPoolNft() public {
        vm.expectRevert(PoolFundingManager.ZeroAddress.selector);
        new PoolFundingManager(address(accessControl), address(invoiceNft), address(0));
    }
    
    // ================================
    // Investment Tests
    // ================================
    
    function test_InvestInPool_Success() public {
        vm.startPrank(investor1);
        
        uint256 investmentAmount = LARGE_INVESTMENT;
        
        fundingManager.investInPool(samplePoolId, investmentAmount);
        
        // Verify investment recorded
        assertEq(
            fundingManager.investorPoolInvestments(samplePoolId, investor1),
            investmentAmount
        );
        assertEq(fundingManager.poolTotalInvestment(samplePoolId), investmentAmount);
        
        // Verify investor and pool arrays updated
        address[] memory poolInvestors = fundingManager.getPoolInvestors(samplePoolId);
        assertEq(poolInvestors.length, 1);
        assertEq(poolInvestors[0], investor1);
        
        uint256[] memory investorPools = fundingManager.getInvestorPools(investor1);
        assertEq(investorPools.length, 1);
        assertEq(investorPools[0], samplePoolId);
        
        vm.stopPrank();
    }
    
    function test_InvestInPool_MultipleInvestors() public {
        uint256 investment1 = 30000e18;
        uint256 investment2 = 40000e18;
        uint256 investment3 = 20000e18;
        
        // First investor
        vm.startPrank(investor1);
        fundingManager.investInPool(samplePoolId, investment1);
        vm.stopPrank();
        
        // Second investor
        vm.startPrank(investor2);
        fundingManager.investInPool(samplePoolId, investment2);
        vm.stopPrank();
        
        // Third investor
        vm.startPrank(investor3);
        fundingManager.investInPool(samplePoolId, investment3);
        vm.stopPrank();
        
        // Verify total investment
        assertEq(
            fundingManager.poolTotalInvestment(samplePoolId),
            investment1 + investment2 + investment3
        );
        
        // Verify individual investments
        assertEq(fundingManager.investorPoolInvestments(samplePoolId, investor1), investment1);
        assertEq(fundingManager.investorPoolInvestments(samplePoolId, investor2), investment2);
        assertEq(fundingManager.investorPoolInvestments(samplePoolId, investor3), investment3);
        
        // Verify investor count
        address[] memory poolInvestors = fundingManager.getPoolInvestors(samplePoolId);
        assertEq(poolInvestors.length, 3);
    }
    
    function test_InvestInPool_RevertNotInvestor() public {
        vm.startPrank(nonUser);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.NotInvestor.selector,
            nonUser
        ));
        fundingManager.investInPool(samplePoolId, MIN_INVESTMENT);
        vm.stopPrank();
    }
    
    function test_InvestInPool_RevertInvalidPoolId() public {
        vm.startPrank(investor1);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.InvalidPoolId.selector,
            999
        ));
        fundingManager.investInPool(999, MIN_INVESTMENT);
        vm.stopPrank();
    }
    
    function test_InvestInPool_RevertInvalidAmount() public {
        vm.startPrank(investor1);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.InvalidAmount.selector,
            0
        ));
        fundingManager.investInPool(samplePoolId, 0);
        vm.stopPrank();
    }
    
    function test_InvestInPool_RevertInvestmentTooSmall() public {
        vm.startPrank(investor1);
        uint256 tooSmall = MIN_INVESTMENT - 1;
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.InvestmentTooSmall.selector,
            tooSmall,
            MIN_INVESTMENT
        ));
        fundingManager.investInPool(samplePoolId, tooSmall);
        vm.stopPrank();
    }
    
    function test_InvestInPool_RevertExceedsMaxInvestment() public {
        vm.startPrank(investor1);
        uint256 maxInvestment = fundingManager.MAX_INVESTMENT_PER_POOL();
        uint256 tooLarge = maxInvestment + 1;
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.ExceedsMaxInvestment.selector,
            tooLarge,
            maxInvestment
        ));
        fundingManager.investInPool(samplePoolId, tooLarge);
        vm.stopPrank();
    }
    
    function test_InvestInPool_RevertPoolNotFundraising() public {
        // Create a new pool that's not in fundraising status
        vm.startPrank(exporter1);
        uint256 newInvoice = invoiceNft.mintInvoice(
            "New Corp",
            "New Importer",
            50000e18,
            30000e18,
            SHIPPING_DATE + 5000
        );
        invoiceNft.finalizeInvoice(newInvoice);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256[] memory newInvoices = new uint256[](1);
        newInvoices[0] = newInvoice;
        uint256 newPoolId = poolNft.createPool("Non-Fundraising Pool", newInvoices);
        // Don't finalize, so it stays in Open status
        vm.stopPrank();
        
        vm.startPrank(investor1);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.PoolNotFundraising.selector,
            newPoolId,
            PoolNFT.PoolStatus.Open
        ));
        fundingManager.investInPool(newPoolId, MIN_INVESTMENT);
        vm.stopPrank();
    }
    
    // ================================
    // Fund Allocation Tests
    // ================================
    
    function test_AllocateFundsToInvoices_Success() public {
        // First, invest in the pool  
        vm.startPrank(investor1);
        uint256 investment = 140000e18; // Enough to cover total loan amount (160k)
        fundingManager.investInPool(samplePoolId, investment);
        vm.stopPrank();
        
        // Check investment was recorded
        assertEq(fundingManager.poolTotalInvestment(samplePoolId), investment);
        
        // Allocate funds
        vm.startPrank(admin);
        fundingManager.allocateFundsToInvoices(samplePoolId);
        vm.stopPrank();
        
        // Verify pool status changed to Funded
        PoolNFT.Pool memory pool = poolNft.getPool(samplePoolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Funded));
        assertEq(pool.totalInvested, investment);
        
        // Verify invoices received proportional funding
        uint256 totalAllocated = 0;
        for (uint256 i = 0; i < sampleInvoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(sampleInvoiceIds[i]);
            assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
            assertTrue(invoice.amountInvested > 0);
            totalAllocated += invoice.amountInvested;
        }
        
        // Total allocated should equal total investment
        assertEq(totalAllocated, investment);
    }
    
    function test_AllocateFundsToInvoices_RevertNotAdmin() public {
        vm.startPrank(investor1);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.NotAdmin.selector,
            investor1
        ));
        fundingManager.allocateFundsToInvoices(samplePoolId);
        vm.stopPrank();
    }
    
    function test_AllocateFundsToInvoices_RevertInsufficientFunds() public {
        // Invest too little (less than 70% of total loan amount)
        vm.startPrank(investor1);
        PoolNFT.Pool memory pool = poolNft.getPool(samplePoolId);
        uint256 insufficient = (pool.totalLoanAmount * 6000) / 10000; // 60%
        fundingManager.investInPool(samplePoolId, insufficient);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 minRequired = (pool.totalLoanAmount * 7000) / 10000; // 70%
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.InsufficientPoolFunds.selector,
            insufficient,
            minRequired
        ));
        fundingManager.allocateFundsToInvoices(samplePoolId);
        vm.stopPrank();
    }
    
    // ================================
    // Profit Distribution Tests
    // ================================
    
    function test_DistributeProfits_Success() public {
        // Setup: invest, allocate, complete pool
        _setupCompletedPool();
        
        vm.startPrank(admin);
        
        PoolNFT.Pool memory pool = poolNft.getPool(samplePoolId);
        uint256 totalInvestment = fundingManager.poolTotalInvestment(samplePoolId);
        
        uint256 expectedPlatformFee = (pool.totalLoanAmount * 100) / 10000; // 1%
        uint256 expectedInvestorRewards = (totalInvestment * 400) / 10000; // 4%
        
        fundingManager.distributeProfits(samplePoolId);
        
        // Verify distribution recorded
        assertTrue(fundingManager.poolProfitsDistributed(samplePoolId));
        assertEq(fundingManager.poolPlatformFees(samplePoolId), expectedPlatformFee);
        assertEq(fundingManager.poolInvestorRewards(samplePoolId), expectedInvestorRewards);
        
        // Verify platform stats updated
        (uint256 totalRevenue, uint256 totalReturns,) = fundingManager.getPlatformStats();
        assertEq(totalRevenue, expectedPlatformFee);
        assertEq(totalReturns, expectedInvestorRewards);
        
        vm.stopPrank();
    }
    
    function test_DistributeProfits_RevertNotCompleted() public {
        // Setup investment without completing the pool
        vm.startPrank(investor1);
        fundingManager.investInPool(samplePoolId, 140000e18);
        vm.stopPrank();
        
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.PoolNotSettled.selector,
            samplePoolId
        ));
        fundingManager.distributeProfits(samplePoolId);
        vm.stopPrank();
    }
    
    function test_DistributeProfits_RevertAlreadyDistributed() public {
        _setupCompletedPool();
        
        vm.startPrank(admin);
        fundingManager.distributeProfits(samplePoolId);
        
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.AlreadyDistributed.selector,
            samplePoolId
        ));
        fundingManager.distributeProfits(samplePoolId);
        vm.stopPrank();
    }
    
    // ================================
    // Investor Return Claims Tests
    // ================================
    
    function test_ClaimInvestorReturns_Success() public {
        uint256 investment = 50000e18;
        _setupCompletedPoolWithInvestment(investor1, investment);
        
        // Distribute profits first
        vm.startPrank(admin);
        fundingManager.distributeProfits(samplePoolId);
        vm.stopPrank();
        
        // Claim returns
        vm.startPrank(investor1);
        
        uint256 totalInvestment = fundingManager.poolTotalInvestment(samplePoolId);
        uint256 totalRewards = fundingManager.poolInvestorRewards(samplePoolId);
        uint256 expectedShare = (investment * totalRewards) / totalInvestment;
        uint256 expectedTotal = investment + expectedShare;
        
        fundingManager.claimInvestorReturns(samplePoolId);
        
        // Verify investment reset (prevents double claiming)
        assertEq(fundingManager.investorPoolInvestments(samplePoolId, investor1), 0);
        
        vm.stopPrank();
    }
    
    function test_ClaimInvestorReturns_RevertNoInvestment() public {
        _setupCompletedPool();
        
        vm.startPrank(admin);
        fundingManager.distributeProfits(samplePoolId);
        vm.stopPrank();
        
        vm.startPrank(investor1); // Never invested
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.NoInvestment.selector,
            investor1,
            samplePoolId
        ));
        fundingManager.claimInvestorReturns(samplePoolId);
        vm.stopPrank();
    }
    
    function test_ClaimInvestorReturns_RevertNotDistributed() public {
        vm.startPrank(investor1);
        fundingManager.investInPool(samplePoolId, 50000e18);
        vm.stopPrank();
        
        vm.startPrank(investor1);
        vm.expectRevert(abi.encodeWithSelector(
            PoolFundingManager.PoolNotSettled.selector,
            samplePoolId
        ));
        fundingManager.claimInvestorReturns(samplePoolId);
        vm.stopPrank();
    }
    
    // ================================
    // View Function Tests
    // ================================
    
    function test_GetInvestorPoolInfo() public {
        uint256 investment = 30000e18;
        vm.startPrank(investor1);
        fundingManager.investInPool(samplePoolId, investment);
        vm.stopPrank();
        
        (uint256 investmentReturned, bool canClaim, uint256 estimatedReturn) = 
            fundingManager.getInvestorPoolInfo(investor1, samplePoolId);
        
        assertEq(investmentReturned, investment);
        assertEq(canClaim, false); // Pool not completed yet
        assertEq(estimatedReturn, investment); // No rewards until completion
    }
    
    function test_GetPoolFundingStats() public {
        uint256 investment1 = 30000e18;
        uint256 investment2 = 20000e18;
        
        vm.startPrank(investor1);
        fundingManager.investInPool(samplePoolId, investment1);
        vm.stopPrank();
        
        vm.startPrank(investor2);
        fundingManager.investInPool(samplePoolId, investment2);
        vm.stopPrank();
        
        (uint256 totalInvested, uint256 investorCount, uint256 fundingProgress) =
            fundingManager.getPoolFundingStats(samplePoolId);
        
        assertEq(totalInvested, investment1 + investment2);
        assertEq(investorCount, 2);
        
        PoolNFT.Pool memory pool = poolNft.getPool(samplePoolId);
        uint256 expectedProgress = ((investment1 + investment2) * 10000) / pool.totalLoanAmount;
        assertEq(fundingProgress, expectedProgress);
    }
    
    function test_GetPlatformStats() public view {
        (uint256 totalRevenue, uint256 totalReturns, uint256 poolsInvested) =
            fundingManager.getPlatformStats();
        
        assertEq(totalRevenue, 0);
        assertEq(totalReturns, 0);
        assertEq(poolsInvested, 0);
    }
    
    // ================================
    // Gas Usage Tests
    // ================================
    
    function test_GasUsage_InvestInPool() public {
        vm.startPrank(investor1);
        
        uint256 gasBefore = gasleft();
        fundingManager.investInPool(samplePoolId, LARGE_INVESTMENT);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for investInPool:", gasUsed);
        assertTrue(gasUsed < 250000); // Should be efficient for complex investment tracking
        
        vm.stopPrank();
    }
    
    function test_GasUsage_AllocateFunds() public {
        vm.startPrank(investor1);
        fundingManager.investInPool(samplePoolId, 140000e18);
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        uint256 gasBefore = gasleft();
        fundingManager.allocateFundsToInvoices(samplePoolId);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for allocateFundsToInvoices with 3 invoices:", gasUsed);
        assertTrue(gasUsed < 500000); // Should be reasonable for 3 invoices
        
        vm.stopPrank();
    }
    
    // ================================
    // Helper Functions
    // ================================
    
    function _setupCompletedPool() internal {
        _setupCompletedPoolWithInvestment(investor1, 140000e18);
    }
    
    function _setupCompletedPoolWithInvestment(address investor, uint256 investment) internal {
        // Invest in pool
        vm.startPrank(investor);
        fundingManager.investInPool(samplePoolId, investment);
        vm.stopPrank();
        
        // Allocate funds
        vm.startPrank(admin);
        fundingManager.allocateFundsToInvoices(samplePoolId);
        
        // Mark all invoices as paid
        for (uint256 i = 0; i < sampleInvoiceIds.length; i++) {
            // First fund each invoice to make it eligible for payment confirmation
            InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(sampleInvoiceIds[i]);
            if (invoice.amountInvested > 0) { // Only if already funded by allocation
                invoiceNft.confirmPayment(sampleInvoiceIds[i]);
            }
        }
        
        // Mark pool as settling and completed
        poolNft.markPoolSettling(samplePoolId);
        uint256 totalDistributed = investment + 10000e18; // Principal + profit
        poolNft.markPoolCompleted(samplePoolId, totalDistributed);
        
        vm.stopPrank();
    }
}