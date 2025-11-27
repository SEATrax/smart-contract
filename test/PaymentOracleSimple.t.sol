// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";
import {PaymentOracle} from "../src/PaymentOracle.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";

contract PaymentOracleTestSimple is Test {
    PlatformAccessControl accessControl;
    PaymentOracle paymentOracle;
    InvoiceNFT invoiceNft;
    PoolNFT poolNft;
    PoolFundingManager fundingManager;

    address admin = makeAddr("admin");
    address oracle1 = makeAddr("oracle1");
    address oracle2 = makeAddr("oracle2");

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
        paymentOracle = new PaymentOracle(
            address(accessControl),
            address(invoiceNft),
            address(poolNft),
            address(fundingManager)
        );

        // Grant admin role to PaymentOracle
        accessControl.grantAdminRole(address(paymentOracle));

        vm.stopPrank();
        
        console2.log("Setup completed successfully");
    }

    function test_Basic() public {
        console2.log("Basic test passed");
        assertTrue(true);
    }
}