// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

// Import all contracts
import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";
import {PaymentOracle} from "../src/PaymentOracle.sol";
import {PlatformAnalytics} from "../src/PlatformAnalytics.sol";

/**
 * @title Deploy Script for Export-Import Funding Platform
 * @notice Comprehensive deployment script for all platform contracts
 * @dev Deploys all contracts in the correct order with proper dependencies and initialization
 */
contract DeployScript is Script {
    // Deployment addresses
    address public accessControl;
    address public invoiceNFT;
    address public poolNFT;
    address public poolFundingManager;
    address public paymentOracle;
    address public platformAnalytics;

    // Configuration parameters
    address public platformAdmin;
    address public initialExporter;
    address public initialInvestor;
    address public initialOracle;
    
    // Network configuration
    string public network;
    uint256 public deploymentTimestamp;

    function setUp() public virtual {
        // Get configuration from environment (fallback to msg.sender for local)
        platformAdmin = msg.sender; // Will be overridden by PLATFORM_ADMIN if set
        try vm.envAddress("PLATFORM_ADMIN") returns (address addr) {
            platformAdmin = addr;
        } catch {}
        
        initialExporter = address(0);
        try vm.envAddress("INITIAL_EXPORTER") returns (address addr) {
            initialExporter = addr;
        } catch {}
        
        initialInvestor = address(0);
        try vm.envAddress("INITIAL_INVESTOR") returns (address addr) {
            initialInvestor = addr;
        } catch {}
        
        initialOracle = address(0);
        try vm.envAddress("INITIAL_ORACLE") returns (address addr) {
            initialOracle = addr;
        } catch {}
        
        network = "local";
        try vm.envString("NETWORK") returns (string memory net) {
            network = net;
        } catch {}
        
        deploymentTimestamp = block.timestamp;
        
        console.log("=== Export-Import Funding Platform Deployment ===");
        console.log("Network:", network);
        console.log("Platform Admin:", platformAdmin);
        console.log("Deployer:", msg.sender);
        console.log("Deployment Timestamp:", deploymentTimestamp);
        console.log("=====================================");
    }

    function run() public virtual {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("\nStarting deployment process...");

        // Phase 1: Deploy Access Control (Foundation)
        console.log("\n=== Phase 1: Deploying Access Control ===");
        deployAccessControl();

        // Phase 2: Deploy Invoice NFT
        console.log("\n=== Phase 2: Deploying Invoice NFT ===");
        deployInvoiceNFT();

        // Phase 3: Deploy Pool NFT
        console.log("\n=== Phase 3: Deploying Pool NFT ===");
        deployPoolNFT();

        // Phase 4: Deploy Pool Funding Manager
        console.log("\n=== Phase 4: Deploying Pool Funding Manager ===");
        deployPoolFundingManager();

        // Phase 5: Deploy Payment Oracle
        console.log("\n=== Phase 5: Deploying Payment Oracle ===");
        deployPaymentOracle();

        // Phase 6: Deploy Platform Analytics
        console.log("\n=== Phase 6: Deploying Platform Analytics ===");
        deployPlatformAnalytics();

        // Phase 7: Initialize contracts and set up roles
        console.log("\n=== Phase 7: Contract Initialization ===");
        initializeContracts();

        vm.stopBroadcast();

        // Log complete deployment summary
        logDeploymentSummary();
        
        // Generate deployment artifacts
        generateDeploymentArtifacts();
    }

    function deployAccessControl() internal {
        console.log("Deploying PlatformAccessControl with admin:", platformAdmin);
        
        accessControl = address(new PlatformAccessControl(platformAdmin));
        
        console.log("[OK] PlatformAccessControl deployed at:", accessControl);
        console.log("   - Platform Admin:", platformAdmin);
        console.log("   - Contract has DEFAULT_ADMIN_ROLE and ADMIN_ROLE");
    }

    function deployInvoiceNFT() internal {
        console.log("Deploying InvoiceNFT with AccessControl:", accessControl);
        
        invoiceNFT = address(new InvoiceNFT(accessControl));
        
        console.log("[OK] InvoiceNFT deployed at:", invoiceNFT);
        console.log("   - Connected to AccessControl:", accessControl);
        console.log("   - NFT Name: 'Shipping Invoice NFT'");
        console.log("   - NFT Symbol: 'INVOICE'");
    }

    function deployPoolNFT() internal {
        console.log("Deploying PoolNFT with dependencies...");
        console.log("   - AccessControl:", accessControl);
        console.log("   - InvoiceNFT:", invoiceNFT);
        
        poolNFT = address(new PoolNFT(accessControl, invoiceNFT));
        
        console.log("[OK] PoolNFT deployed at:", poolNFT);
        console.log("   - NFT Name: 'Shipping Invoice Pool NFT'");
        console.log("   - NFT Symbol: 'POOL'");
        console.log("   - Max invoices per pool: 50");
    }

    function deployPoolFundingManager() internal {
        console.log("Deploying PoolFundingManager with dependencies...");
        console.log("   - AccessControl:", accessControl);
        console.log("   - InvoiceNFT:", invoiceNFT);
        console.log("   - PoolNFT:", poolNFT);
        
        poolFundingManager = address(new PoolFundingManager(
            accessControl,
            invoiceNFT,
            poolNFT
        ));
        
        console.log("[OK] PoolFundingManager deployed at:", poolFundingManager);
        console.log("   - Platform fee rate: 1% (100 basis points)");
        console.log("   - Investor yield rate: 4% (400 basis points)");
        console.log("   - Min investment: 1,000 tokens");
        console.log("   - Max investment per pool: 1,000,000 tokens");
    }

    function deployPaymentOracle() internal {
        console.log("Deploying PaymentOracle with dependencies...");
        console.log("   - AccessControl:", accessControl);
        console.log("   - InvoiceNFT:", invoiceNFT);
        console.log("   - PoolNFT:", poolNFT);
        console.log("   - PoolFundingManager:", poolFundingManager);
        
        paymentOracle = address(new PaymentOracle(
            accessControl,
            invoiceNFT,
            poolNFT,
            poolFundingManager
        ));
        
        console.log("[OK] PaymentOracle deployed at:", paymentOracle);
        console.log("   - Required confirmations: 2");
        console.log("   - Confirmation window: 7 days");
        console.log("   - Grace period: 2 days");
    }

    function deployPlatformAnalytics() internal {
        console.log("Deploying PlatformAnalytics with dependencies...");
        console.log("   - AccessControl:", accessControl);
        console.log("   - InvoiceNFT:", invoiceNFT);
        console.log("   - PoolNFT:", poolNFT);
        console.log("   - PoolFundingManager:", poolFundingManager);
        console.log("   - PaymentOracle:", paymentOracle);
        
        platformAnalytics = address(new PlatformAnalytics(
            accessControl,
            invoiceNFT,
            poolNFT,
            poolFundingManager,
            paymentOracle
        ));
        
        console.log("[OK] PlatformAnalytics deployed at:", platformAnalytics);
        console.log("   - Analytics tracking enabled");
        console.log("   - Historical data support");
        console.log("   - Risk assessment framework");
    }

    function initializeContracts() internal {
        console.log("Initializing contracts and setting up roles...");
        
        PlatformAccessControl accessControlContract = PlatformAccessControl(accessControl);
        
        // Grant initial roles if addresses are provided
        if (initialExporter != address(0)) {
            console.log("Granting EXPORTER_ROLE to:", initialExporter);
            accessControlContract.grantExporterRole(initialExporter);
        }
        
        if (initialInvestor != address(0)) {
            console.log("Granting INVESTOR_ROLE to:", initialInvestor);
            accessControlContract.grantInvestorRole(initialInvestor);
        }
        
        // Initialize oracle if provided
        if (initialOracle != address(0)) {
            console.log("Authorizing initial oracle:", initialOracle);
            PaymentOracle(paymentOracle).authorizeOracle(initialOracle);
        }
        
        console.log("[OK] Contract initialization completed");
    }

    function logDeploymentSummary() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", network);
        console.log("Deployment Timestamp:", deploymentTimestamp);
        console.log("Platform Admin:", platformAdmin);
        console.log("");
        console.log("Contract Addresses:");
        console.log("  PlatformAccessControl: ", accessControl);
        console.log("  InvoiceNFT:            ", invoiceNFT);
        console.log("  PoolNFT:               ", poolNFT);
        console.log("  PoolFundingManager:    ", poolFundingManager);
        console.log("  PaymentOracle:         ", paymentOracle);
        console.log("  PlatformAnalytics:     ", platformAnalytics);
        console.log("");
        console.log("Configuration:");
        console.log("  Platform Fee: 1% (100 basis points)");
        console.log("  Investor Yield: 4% (400 basis points)");
        console.log("  Min Investment: 1,000 tokens");
        console.log("  Max Investment/Pool: 1,000,000 tokens");
        console.log("  Oracle Confirmations: 2 required");
        console.log("========================");
    }

    function generateDeploymentArtifacts() internal view {
        console.log("\n=== DEPLOYMENT ARTIFACTS ===");
        console.log("Environment variables for testing:");
        console.log("");
        console.log("export NETWORK=", network);
        console.log("export PLATFORM_ADMIN=", platformAdmin);
        console.log("export ACCESS_CONTROL=", accessControl);
        console.log("export INVOICE_NFT=", invoiceNFT);
        console.log("export POOL_NFT=", poolNFT);
        console.log("export POOL_FUNDING_MANAGER=", poolFundingManager);
        console.log("export PAYMENT_ORACLE=", paymentOracle);
        console.log("export PLATFORM_ANALYTICS=", platformAnalytics);
        console.log("");
        console.log("Verification commands (after deployment):");
        console.log("forge verify-contract", accessControl, "PlatformAccessControl");
        console.log("  --network", network);
        console.log("forge verify-contract", invoiceNFT, "InvoiceNFT");
        console.log("  --constructor-args $(cast abi-encode 'constructor(address)'", accessControl, ")");
        console.log("  --network", network);
        console.log("forge verify-contract", poolNFT, "PoolNFT"); 
        console.log("  --constructor-args $(cast abi-encode 'constructor(address,address)'", accessControl, invoiceNFT, ")");
        console.log("  --network", network);
        console.log("=====================");
    }
}