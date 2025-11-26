// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/AccessControl.sol";
import "../src/InvoiceNFT.sol";
import "../src/PoolNFT.sol";
import "../src/PoolFundingManager.sol";

contract MinimalReproTest is Test {
    PlatformAccessControl accessControl;
    InvoiceNFT invoiceNft;
    PoolNFT poolNft;
    PoolFundingManager fundingManager;
    
    address admin = address(1);
    address exporter = address(2);
    address investor = address(3);
    
    function setUp() public {
        vm.startPrank(admin);
        
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        poolNft = new PoolNFT(address(accessControl), address(invoiceNft));
        fundingManager = new PoolFundingManager(address(accessControl), address(invoiceNft), address(poolNft));
        
        accessControl.grantExporterRole(exporter);
        accessControl.grantInvestorRole(investor);
        // Grant admin role to PoolFundingManager contract
        accessControl.grantAdminRole(address(fundingManager));
        
        vm.stopPrank();
    }
    
    function testMinimalReproduce() public {
        // Create an invoice
        vm.startPrank(exporter);
        uint256 invoiceId = invoiceNft.mintInvoice(
            "Test Corp",
            "Test Import",
            100e18, // 100 ETH shipping
            70e18,  // 70 ETH loan
            block.timestamp + 30 days
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Create a pool
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = invoiceId;
        uint256 poolId = poolNft.createPool("Test Pool", invoiceIds);
        poolNft.finalizePool(poolId);
        vm.stopPrank();
        
        // Invest
        vm.startPrank(investor);
        fundingManager.investInPool(poolId, 1000e18); // Use minimum investment
        vm.stopPrank();
        
        // This should trigger the underflow
        vm.startPrank(admin);
        fundingManager.allocateFundsToInvoices(poolId);
        vm.stopPrank();
    }
}