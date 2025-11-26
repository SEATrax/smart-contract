// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

contract DebugTest is Test {
    function testArithmeticCalculation() public {
        uint256 totalInvestment = 140e18; // 140 ETH
        uint256 totalLoanAmount = 160e18;  // 160 ETH
        
        // Invoice amounts: 70, 50, 40 ETH
        uint256[] memory invoiceAmounts = new uint256[](3);
        invoiceAmounts[0] = 70e18;
        invoiceAmounts[1] = 50e18;
        invoiceAmounts[2] = 40e18;
        
        console.log("Total Investment:", totalInvestment);
        console.log("Total Loan Amount:", totalLoanAmount);
        
        for (uint256 i = 0; i < invoiceAmounts.length; i++) {
            uint256 allocation = (totalInvestment * invoiceAmounts[i]) / totalLoanAmount;
            console.log("Invoice", i + 1, "Amount:", invoiceAmounts[i]);
            console.log("Invoice", i + 1, "Allocation:", allocation);
        }
    }
}