// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";

/**
 * @title Phase4Verification
 * @notice Lightweight verification tests for Phase 4 Pool NFT System
 * @dev Focused on core functionality without complex integration scenarios
 */
contract Phase4Verification is Test {
    PlatformAccessControl internal accessControl;
    InvoiceNFT internal invoiceNft;
    PoolNFT internal poolNft;

    address internal admin = makeAddr("admin");
    address internal exporter = makeAddr("exporter");

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy contracts
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        poolNft = new PoolNFT(address(accessControl), address(invoiceNft));
        
        // Setup roles
        accessControl.grantExporterRole(exporter);
        
        vm.stopPrank();
    }

    function test_PoolNFTDeployment() public view {
        console2.log("=== Phase 4 Pool NFT Deployment Verification ===");
        
        // Verify contract deployments
        assertTrue(address(poolNft) != address(0), "PoolNFT not deployed");
        assertTrue(address(invoiceNft) != address(0), "InvoiceNFT not deployed");
        assertTrue(address(accessControl) != address(0), "AccessControl not deployed");
        
        // Verify contract linkages
        assertEq(address(poolNft.ACCESS_CONTROL()), address(accessControl));
        assertEq(address(poolNft.INVOICE_NFT()), address(invoiceNft));
        
        console2.log("[OK] All contracts deployed and linked correctly");
    }

    function test_BasicPoolCreation() public {
        console2.log("=== Phase 4 Basic Pool Creation ===");
        
        // Create and finalize invoice
        vm.startPrank(exporter);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Test Exporter",
            "Test Importer", 
            100000e18, // $100k
            70000e18,  // $70k loan
            block.timestamp + 86400
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Create pool
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        
        uint256 poolId = poolNft.createPool("Test Pool", invoiceIds);
        
        // Verify pool creation
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        assertEq(pool.invoiceCount, 1);
        assertEq(pool.totalLoanAmount, 70000e18);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Open));
        assertEq(poolNft.ownerOf(poolId), admin);
        
        vm.stopPrank();
        
        console2.log("[OK] Pool creation working correctly");
    }

    function test_PoolStatusTransitions() public {
        console2.log("=== Phase 4 Pool Status Transitions ===");
        
        // Setup invoice
        vm.startPrank(exporter);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Status Test Corp",
            "Test Importer",
            50000e18,
            30000e18,
            block.timestamp + 86400
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Create pool
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Status Test Pool", invoiceIds);
        
        // Test: Open → Fundraising
        poolNft.finalizePool(poolId);
        PoolNFT.Pool memory pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Fundraising));
        
        // Test: Fundraising → Funded
        poolNft.markPoolFunded(poolId, 25500e18); // 85% of loan amount
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Funded));
        assertEq(pool.totalInvested, 25500e18);
        
        // Test: Funded → Settling
        // First, add funding to the invoice so it becomes Funded status
        invoiceNft.addFunding(invoiceId, 25500e18); // Same amount as pool funding
        
        // Then mark invoice as paid (required before pool can be set to settling)
        invoiceNft.confirmPayment(invoiceId);
        
        poolNft.markPoolSettling(poolId);
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Settling));
        
        // Test: Settling → Completed
        poolNft.markPoolCompleted(poolId, 28000e18); // Principal + profit
        pool = poolNft.getPool(poolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Completed));
        assertEq(pool.totalDistributed, 28000e18);
        
        vm.stopPrank();
        
        console2.log("[OK] All pool status transitions working");
    }

    function test_PoolInvoiceRelationship() public {
        console2.log("=== Phase 4 Pool-Invoice Relationship ===");
        
        // Create two invoices
        vm.startPrank(exporter);
        uint256 invoice1 = invoiceNft.mintInvoice("Corp1", "Importer1", 50000e18, 30000e18, block.timestamp + 86400);
        uint256 invoice2 = invoiceNft.mintInvoice("Corp2", "Importer2", 60000e18, 40000e18, block.timestamp + 86400);
        invoiceNft.finalizeInvoice(invoice1);
        invoiceNft.finalizeInvoice(invoice2);
        vm.stopPrank();
        
        // Create pool with first invoice
        vm.startPrank(admin);
        uint256[] memory invoices1 = new uint256[](1);
        invoices1[0] = invoice1;
        uint256 pool1 = poolNft.createPool("Pool 1", invoices1);
        
        // Verify relationship
        assertEq(poolNft.getInvoicePool(invoice1), pool1);
        assertEq(poolNft.getInvoicePool(invoice2), 0); // Not in any pool
        
        // Create second pool with second invoice
        uint256[] memory invoices2 = new uint256[](1);
        invoices2[0] = invoice2;
        uint256 pool2 = poolNft.createPool("Pool 2", invoices2);
        
        // Verify both relationships
        assertEq(poolNft.getInvoicePool(invoice1), pool1);
        assertEq(poolNft.getInvoicePool(invoice2), pool2);
        
        vm.stopPrank();
        
        console2.log("[OK] Pool-invoice relationships working correctly");
    }

    function test_PoolValidation() public {
        console2.log("=== Phase 4 Pool Validation ===");
        
        // Create invoice
        vm.startPrank(exporter);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Validation Corp",
            "Test Importer",
            80000e18,
            50000e18,
            block.timestamp + 86400
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Create and finalize pool
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Validation Pool", invoiceIds);
        
        // Pool not eligible before fundraising
        assertFalse(poolNft.isPoolEligibleForFunding(poolId));
        assertFalse(poolNft.validatePoolForFunding(poolId));
        
        // Make pool eligible
        poolNft.finalizePool(poolId);
        assertTrue(poolNft.isPoolEligibleForFunding(poolId));
        assertTrue(poolNft.validatePoolForFunding(poolId));
        
        vm.stopPrank();
        
        console2.log("[OK] Pool validation logic working correctly");
    }
}