// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";

contract DebugOverflowTest is Test {
    PlatformAccessControl accessControl;
    InvoiceNFT invoiceNft;
    PoolNFT poolNft;
    PoolFundingManager fundingManager;

    address admin = makeAddr("admin");
    address exporter = makeAddr("exporter");
    address investor = makeAddr("investor");

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
        accessControl.grantAdminRole(address(fundingManager));
        
        vm.stopPrank();
    }

    function test_DebugOverflow() public {
        // Test uint88 limits first
        uint256 testValue = 84000e18;
        console2.log("Test value:", testValue);
        console2.log("uint88 max:", type(uint88).max);
        console2.log("Fits in uint88:", testValue <= type(uint88).max);
        
        // Create exactly the same scenario as the failing test
        vm.startPrank(exporter);
        uint256 invoice1 = invoiceNft.mintInvoice("Corp A", "Import", 50000e18, 35000e18, block.timestamp + 86400);
        invoiceNft.finalizeInvoice(invoice1);
        
        uint256 invoice2 = invoiceNft.mintInvoice("Corp A", "Import", 30000e18, 21000e18, block.timestamp + 86400);
        invoiceNft.finalizeInvoice(invoice2);
        
        uint256 invoice3 = invoiceNft.mintInvoice("Corp B", "Import", 40000e18, 28000e18, block.timestamp + 86400);
        invoiceNft.finalizeInvoice(invoice3);
        vm.stopPrank();

        console2.log("About to create pool...");
        
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](3);
        invoiceIds[0] = invoice1;
        invoiceIds[1] = invoice2;
        invoiceIds[2] = invoice3;
        
        try poolNft.createPool("Test Pool", invoiceIds) returns (uint256 poolId) {
            console2.log("Pool created successfully, ID:", poolId);
            poolNft.finalizePool(poolId);
            vm.stopPrank();
            
            // Try investment
            vm.startPrank(investor);
            try fundingManager.investInPool(poolId, 90000e18) {
                console2.log("Investment successful");
            } catch (bytes memory reason) {
                console2.log("Investment failed:");
                console2.logBytes(reason);
                return;
            }
            vm.stopPrank();
            
            // Try allocation
            vm.startPrank(admin);
            
            // Debug invoice states before allocation
            console2.log("\n=== Invoice states before allocation ===");
            InvoiceNFT.Invoice memory inv1 = invoiceNft.getInvoice(invoice1);
            InvoiceNFT.Invoice memory inv2 = invoiceNft.getInvoice(invoice2);
            InvoiceNFT.Invoice memory inv3 = invoiceNft.getInvoice(invoice3);
            
            console2.log("Invoice 1 - amountInvested:", inv1.amountInvested, "loanAmount:", inv1.loanAmount);
            console2.log("Invoice 2 - amountInvested:", inv2.amountInvested, "loanAmount:", inv2.loanAmount);
            console2.log("Invoice 3 - amountInvested:", inv3.amountInvested, "loanAmount:", inv3.loanAmount);
            
            try fundingManager.allocateFundsToInvoices(poolId) {
                console2.log("Allocation successful");
            } catch (bytes memory reason) {
                console2.log("Allocation failed:");
                console2.logBytes(reason);
            }
            vm.stopPrank();
        } catch (bytes memory reason) {
            console2.log("Pool creation failed:");
            console2.logBytes(reason);
            return;
        }
        vm.stopPrank();
    }
}