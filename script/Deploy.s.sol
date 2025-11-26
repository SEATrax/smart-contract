// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

// Import contracts (will be uncommented as we implement them)
// import {AccessControl} from "../src/AccessControl.sol";
// import {InvoiceNFT} from "../src/InvoiceNFT.sol";
// import {PoolManager} from "../src/PoolManager.sol";
// import {InvestmentPool} from "../src/InvestmentPool.sol";
// import {PaymentEscrow} from "../src/PaymentEscrow.sol";
// import {PaymentOracle} from "../src/PaymentOracle.sol";

/**
 * @title Deploy Script
 * @notice Deployment script for Export-Import Funding Platform contracts
 * @dev This script deploys all contracts in the correct order with proper dependencies
 */
contract DeployScript is Script {
    // Deployment addresses (will be populated during deployment)
    address public accessControl;
    address public invoiceNFT;
    address public poolManager;
    address public investmentPool;
    address public paymentEscrow;
    address public paymentOracle;

    // Configuration parameters
    address public admin;
    address public investmentManager;
    uint256 public platformFeePercent = 100; // 1% in basis points (10000 = 100%)
    uint256 public investorYieldPercent = 400; // 4% in basis points

    function setUp() public {
        // Get deployer address
        admin = vm.envOr("ADMIN_ADDRESS", msg.sender);
        investmentManager = vm.envOr("INVESTMENT_MANAGER_ADDRESS", msg.sender);
        
        console.log("=== Export-Import Funding Platform Deployment ===");
        console.log("Admin address:", admin);
        console.log("Investment Manager address:", investmentManager);
        console.log("Platform fee:", platformFeePercent, "basis points");
        console.log("Investor yield:", investorYieldPercent, "basis points");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy Access Control
        console.log("\n=== Deploying Access Control ===");
        deployAccessControl();

        // Phase 2: Deploy Invoice NFT
        console.log("\n=== Deploying Invoice NFT ===");
        deployInvoiceNFT();

        // Phase 3: Deploy Pool Manager
        console.log("\n=== Deploying Pool Manager ===");
        deployPoolManager();

        // Phase 4: Deploy Investment Pool
        console.log("\n=== Deploying Investment Pool ===");
        deployInvestmentPool();

        // Phase 5: Deploy Payment Escrow
        console.log("\n=== Deploying Payment Escrow ===");
        deployPaymentEscrow();

        // Phase 6: Deploy Payment Oracle
        console.log("\n=== Deploying Payment Oracle ===");
        deployPaymentOracle();

        // Phase 7: Configure contracts
        console.log("\n=== Configuring Contracts ===");
        configureContracts();

        vm.stopBroadcast();

        // Log deployment summary
        logDeploymentSummary();
    }

    function deployAccessControl() internal {
        console.log("Deploying AccessControl...");
        // accessControl = address(new AccessControl(admin));
        // console.log("AccessControl deployed at:", accessControl);
        console.log("AccessControl deployment - TODO: Implement in Phase 2");
    }

    function deployInvoiceNFT() internal {
        console.log("Deploying InvoiceNFT...");
        // invoiceNFT = address(new InvoiceNFT(accessControl));
        // console.log("InvoiceNFT deployed at:", invoiceNFT);
        console.log("InvoiceNFT deployment - TODO: Implement in Phase 3");
    }

    function deployPoolManager() internal {
        console.log("Deploying PoolManager...");
        // poolManager = address(new PoolManager(accessControl, invoiceNFT));
        // console.log("PoolManager deployed at:", poolManager);
        console.log("PoolManager deployment - TODO: Implement in Phase 4");
    }

    function deployInvestmentPool() internal {
        console.log("Deploying InvestmentPool...");
        // investmentPool = address(new InvestmentPool(accessControl, poolManager));
        // console.log("InvestmentPool deployed at:", investmentPool);
        console.log("InvestmentPool deployment - TODO: Implement in Phase 4");
    }

    function deployPaymentEscrow() internal {
        console.log("Deploying PaymentEscrow...");
        // paymentEscrow = address(new PaymentEscrow(accessControl, invoiceNFT, platformFeePercent, investorYieldPercent));
        // console.log("PaymentEscrow deployed at:", paymentEscrow);
        console.log("PaymentEscrow deployment - TODO: Implement in Phase 5");
    }

    function deployPaymentOracle() internal {
        console.log("Deploying PaymentOracle...");
        // paymentOracle = address(new PaymentOracle(accessControl, paymentEscrow));
        // console.log("PaymentOracle deployed at:", paymentOracle);
        console.log("PaymentOracle deployment - TODO: Implement in Phase 6");
    }

    function configureContracts() internal {
        console.log("Setting up contract permissions and configurations...");
        
        // Set up roles and permissions
        // AccessControl(accessControl).grantRole(INVESTMENT_MANAGER_ROLE, investmentManager);
        
        // Configure contract addresses in other contracts
        // InvoiceNFT(invoiceNFT).setPoolManager(poolManager);
        // PoolManager(poolManager).setInvestmentPool(investmentPool);
        // PaymentEscrow(paymentEscrow).setPaymentOracle(paymentOracle);
        
        console.log("Contract configuration - TODO: Implement in respective phases");
    }

    function logDeploymentSummary() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("AccessControl:", accessControl);
        console.log("InvoiceNFT:", invoiceNFT);
        console.log("PoolManager:", poolManager);
        console.log("InvestmentPool:", investmentPool);
        console.log("PaymentEscrow:", paymentEscrow);
        console.log("PaymentOracle:", paymentOracle);
        console.log("=========================");
        
        // Save deployment addresses to file (for testing and interaction)
        // This would be useful for integration tests and frontend integration
        console.log("\nSave these addresses for testing and integration:");
        console.log("export ACCESS_CONTROL=", accessControl);
        console.log("export INVOICE_NFT=", invoiceNFT);
        console.log("export POOL_MANAGER=", poolManager);
        console.log("export INVESTMENT_POOL=", investmentPool);
        console.log("export PAYMENT_ESCROW=", paymentEscrow);
        console.log("export PAYMENT_ORACLE=", paymentOracle);
    }
}