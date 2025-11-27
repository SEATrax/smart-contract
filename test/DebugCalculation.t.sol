// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PoolNFT} from "../src/PoolNFT.sol";
import {PoolFundingManager} from "../src/PoolFundingManager.sol";

// Test the exact allocation calculation
contract DebugCalculationTest is Test {
    function test_CalculationOverflow() public {
        // Test the exact calculation from allocateFundsToInvoices
        uint256 totalInvestment = 90000e18;
        uint256 poolTotalLoanAmount = 84000e18;
        
        // Individual invoice loan amounts
        uint256 invoice1Loan = 35000e18;
        uint256 invoice2Loan = 21000e18; 
        uint256 invoice3Loan = 28000e18;
        
        console2.log("=== Calculation Test ===");
        console2.log("Total investment:", totalInvestment);
        console2.log("Pool total loan:", poolTotalLoanAmount);
        
        // Test each calculation
        console2.log("\n--- Invoice 1 ---");
        console2.log("Loan amount:", invoice1Loan);
        uint256 allocation1 = (totalInvestment * invoice1Loan) / poolTotalLoanAmount;
        console2.log("Calculated allocation:", allocation1);
        console2.log("Fits in uint128:", allocation1 <= type(uint128).max);
        
        console2.log("\n--- Invoice 2 ---");
        console2.log("Loan amount:", invoice2Loan);
        uint256 allocation2 = (totalInvestment * invoice2Loan) / poolTotalLoanAmount;
        console2.log("Calculated allocation:", allocation2);
        console2.log("Fits in uint128:", allocation2 <= type(uint128).max);
        
        console2.log("\n--- Invoice 3 ---");
        console2.log("Loan amount:", invoice3Loan);
        uint256 allocation3 = (totalInvestment * invoice3Loan) / poolTotalLoanAmount;
        console2.log("Calculated allocation:", allocation3);
        console2.log("Fits in uint128:", allocation3 <= type(uint128).max);
        
        console2.log("\n--- Sum check ---");
        uint256 totalAllocated = allocation1 + allocation2 + allocation3;
        console2.log("Total allocated:", totalAllocated);
        console2.log("Difference from investment:", totalInvestment - totalAllocated);
    }
}