// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import "./Deploy.s.sol";

/**
 * @title Local Deployment Script
 * @notice Script for deploying contracts to local Anvil/Foundry test environment
 * @dev Includes test data setup and demo scenario initialization
 */
contract DeployLocalScript is DeployScript {
    // Test accounts for local deployment
    address public testExporter1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public testExporter2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public testInvestor1 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address public testInvestor2 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address public testOracle = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;

    function setUp() public override {
        // Set test configuration
        platformAdmin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default Anvil account 0
        initialExporter = testExporter1;
        initialInvestor = testInvestor1;
        initialOracle = testOracle;
        network = "local";
        
        console.log("=== LOCAL DEPLOYMENT CONFIGURATION ===");
        console.log("Platform Admin:", platformAdmin);
        console.log("Test Exporter 1:", testExporter1);
        console.log("Test Exporter 2:", testExporter2);
        console.log("Test Investor 1:", testInvestor1);
        console.log("Test Investor 2:", testInvestor2);
        console.log("Test Oracle:", testOracle);
        console.log("======================================");
    }

    function run() public override {
        // Get deployer key and start broadcast
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\nStarting deployment process...");
        
        // Deploy all contracts using the parent logic
        deployAllContracts();
        
        // Add local-specific initialization (still within broadcast)
        console.log("\n=== LOCAL ENVIRONMENT SETUP ===");
        setupTestEnvironment();
        
        vm.stopBroadcast();
        
        // Print deployment summary
        logDeploymentSummary();
        
        console.log("=====================");
    }
    
    function deployAllContracts() internal {
        // Deploy contracts in order
        deployAccessControl();
        deployInvoiceNFT();
        deployPoolNFT();
        deployPoolFundingManager();
        deployPaymentOracle();
        deployPlatformAnalytics();
        initializeContracts();
    }

    function setupTestEnvironment() internal {
        console.log("Setting up test environment with demo data...");
        
        // Grant additional roles for testing (using the stored contract addresses)
        console.log("Granting additional test roles...");
        console.log("Granting EXPORTER_ROLE to:", testExporter2);
        PlatformAccessControl(accessControl).grantExporterRole(testExporter2);
        
        console.log("Granting INVESTOR_ROLE to:", testInvestor2);
        PlatformAccessControl(accessControl).grantInvestorRole(testInvestor2);
        
        console.log("[OK] Test environment setup completed");
        console.log("");
        console.log("=== DEMO SCENARIO READY ===");
        console.log("You can now test the complete platform flow:");
        console.log("1. Exporters can create and finalize invoices");
        console.log("2. Admins can create pools with invoices");
        console.log("3. Investors can invest in pools");
        console.log("4. Oracles can confirm payments");
        console.log("5. Platform analytics can be updated");
        console.log("========================");
        
        // Log interaction examples
        logInteractionExamples();
    }

    function logInteractionExamples() internal view {
        console.log("\n=== INTERACTION EXAMPLES ===");
        console.log("# Create an invoice (as exporter):");
        console.log("cast send", invoiceNFT);
        console.log("  'mintInvoice(string,string,uint256,uint256,uint256)'");
        console.log("  'Acme Corp' 'Import Co' 5000000000000000000000 3500000000000000000000 $(date +%s)");
        console.log("  --from", testExporter1, "--private-key <exporter-key>");
        console.log("");
        console.log("# Finalize invoice:");
        console.log("cast send", invoiceNFT, "'finalizeInvoice(uint256)' 1");
        console.log("  --from", testExporter1, "--private-key <exporter-key>");
        console.log("");
        console.log("# Create pool (as admin):");
        console.log("cast send", poolNFT);
        console.log("  'createPool(string,uint256[])' 'Test Pool' '[1]'");
        console.log("  --from", platformAdmin, "--private-key <admin-key>");
        console.log("");
        console.log("# Finalize pool for fundraising:");
        console.log("cast send", poolNFT, "'finalizePool(uint256)' 1");
        console.log("  --from", platformAdmin, "--private-key <admin-key>");
        console.log("");
        console.log("# Invest in pool:");
        console.log("cast send", poolFundingManager);
        console.log("  'investInPool(uint256,uint256)' 1 2000000000000000000000");
        console.log("  --from", testInvestor1, "--private-key <investor-key>");
        console.log("========================");
    }
}