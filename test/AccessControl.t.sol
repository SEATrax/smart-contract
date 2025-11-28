// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";

/**
 * @title AccessControl Test Suite
 * @notice Comprehensive tests for the Platform Access Control system
 * @dev Tests all role management, modifiers, and access control functionality
 */
contract AccessControlTest is Test {
    // ================================
    // Test Contract Instance
    // ================================
    
    PlatformAccessControl public accessControl;

    // ================================
    // Test Addresses
    // ================================
    
    address public platformAdmin = makeAddr("platformAdmin");
    address public admin1 = makeAddr("admin1");
    address public admin2 = makeAddr("admin2");
    address public exporter1 = makeAddr("exporter1");
    address public exporter2 = makeAddr("exporter2");
    address public investor1 = makeAddr("investor1");
    address public investor2 = makeAddr("investor2");
    address public unauthorizedUser = makeAddr("unauthorizedUser");

    // ================================
    // Events for Testing
    // ================================
    
    event AdminRoleGranted(address indexed account, address indexed grantor);
    event AdminRoleRevoked(address indexed account, address indexed revoker);
    event ExporterRoleGranted(address indexed account, address indexed grantor);
    event ExporterRoleRevoked(address indexed account, address indexed revoker);
    event InvestorRoleGranted(address indexed account, address indexed grantor);
    event InvestorRoleRevoked(address indexed account, address indexed revoker);
    event PlatformAdminChanged(address indexed previousAdmin, address indexed newAdmin);

    // ================================
    // Setup
    // ================================
    
    function setUp() public {
        // Deploy the access control contract with platform admin
        accessControl = new PlatformAccessControl(platformAdmin);
    }

    // ================================
    // Constructor Tests
    // ================================
    
    function testConstructor() public view {
        // Platform admin should be set correctly
        assertEq(accessControl.platformAdmin(), platformAdmin);
        
        // Platform admin should have both DEFAULT_ADMIN_ROLE and ADMIN_ROLE
        assertTrue(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), platformAdmin));
        assertTrue(accessControl.isAdmin(platformAdmin));
        
        // Only one admin should exist initially
        assertEq(accessControl.getAdminCount(), 1);
        assertEq(accessControl.getAdminByIndex(0), platformAdmin);
    }

    function testConstructorWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        new PlatformAccessControl(address(0));
    }

    // ================================
    // Admin Role Management Tests
    // ================================
    
    function testGrantAdminRole() public {
        vm.startPrank(platformAdmin);
        
        // Expect event emission
        vm.expectEmit(true, true, false, true);
        emit AdminRoleGranted(admin1, platformAdmin);
        
        accessControl.grantAdminRole(admin1);
        
        // Verify admin role granted
        assertTrue(accessControl.isAdmin(admin1));
        assertEq(accessControl.getAdminCount(), 2);
        
        vm.stopPrank();
    }

    function testGrantAdminRoleAlreadyAssigned() public {
        vm.startPrank(platformAdmin);
        
        accessControl.grantAdminRole(admin1);
        
        // Should revert when trying to grant again
        vm.expectRevert(abi.encodeWithSignature("RoleAlreadyAssigned(address,bytes32)", admin1, accessControl.ADMIN_ROLE()));
        accessControl.grantAdminRole(admin1);
        
        vm.stopPrank();
    }

    function testGrantAdminRoleUnauthorized() public {
        vm.startPrank(unauthorizedUser);
        
        vm.expectRevert(); // AccessControl: account is missing role
        accessControl.grantAdminRole(admin1);
        
        vm.stopPrank();
    }

    function testRevokeAdminRole() public {
        vm.startPrank(platformAdmin);
        
        // First grant the role
        accessControl.grantAdminRole(admin1);
        
        // Expect event emission for revocation
        vm.expectEmit(true, true, false, true);
        emit AdminRoleRevoked(admin1, platformAdmin);
        
        // Revoke the role
        accessControl.revokeAdminRole(admin1);
        
        // Verify admin role revoked
        assertFalse(accessControl.isAdmin(admin1));
        assertEq(accessControl.getAdminCount(), 1);
        
        vm.stopPrank();
    }

    function testRevokeAdminRoleNotAssigned() public {
        vm.startPrank(platformAdmin);
        
        vm.expectRevert(abi.encodeWithSignature("RoleNotAssigned(address,bytes32)", admin1, accessControl.ADMIN_ROLE()));
        accessControl.revokeAdminRole(admin1);
        
        vm.stopPrank();
    }

    // ================================
    // Exporter Role Management Tests
    // ================================
    
    function testGrantExporterRole() public {
        vm.startPrank(platformAdmin);
        
        // Expect event emission
        vm.expectEmit(true, true, false, true);
        emit ExporterRoleGranted(exporter1, platformAdmin);
        
        accessControl.grantExporterRole(exporter1);
        
        // Verify exporter role granted
        assertTrue(accessControl.isExporter(exporter1));
        assertEq(accessControl.getExporterCount(), 1);
        assertEq(accessControl.getExporterByIndex(0), exporter1);
        
        vm.stopPrank();
    }

    function testGrantExporterRoleByAdmin() public {
        // First grant admin role to admin1
        vm.prank(platformAdmin);
        accessControl.grantAdminRole(admin1);
        
        // Admin1 should be able to grant exporter role
        vm.startPrank(admin1);
        
        vm.expectEmit(true, true, false, true);
        emit ExporterRoleGranted(exporter1, admin1);
        
        accessControl.grantExporterRole(exporter1);
        assertTrue(accessControl.isExporter(exporter1));
        
        vm.stopPrank();
    }

    function testGrantExporterRoleUnauthorized() public {
        vm.startPrank(unauthorizedUser);
        
        vm.expectRevert(abi.encodeWithSignature("NotAdmin(address)", unauthorizedUser));
        accessControl.grantExporterRole(exporter1);
        
        vm.stopPrank();
    }

    function testRevokeExporterRole() public {
        vm.startPrank(platformAdmin);
        
        // First grant the role
        accessControl.grantExporterRole(exporter1);
        
        // Expect event emission for revocation
        vm.expectEmit(true, true, false, true);
        emit ExporterRoleRevoked(exporter1, platformAdmin);
        
        // Revoke the role
        accessControl.revokeExporterRole(exporter1);
        
        // Verify exporter role revoked
        assertFalse(accessControl.isExporter(exporter1));
        assertEq(accessControl.getExporterCount(), 0);
        
        vm.stopPrank();
    }

    // ================================
    // Investor Role Management Tests
    // ================================
    
    function testGrantInvestorRole() public {
        vm.startPrank(platformAdmin);
        
        // Expect event emission
        vm.expectEmit(true, true, false, true);
        emit InvestorRoleGranted(investor1, platformAdmin);
        
        accessControl.grantInvestorRole(investor1);
        
        // Verify investor role granted
        assertTrue(accessControl.isInvestor(investor1));
        assertEq(accessControl.getInvestorCount(), 1);
        assertEq(accessControl.getInvestorByIndex(0), investor1);
        
        vm.stopPrank();
    }

    function testRevokeInvestorRole() public {
        vm.startPrank(platformAdmin);
        
        // First grant the role
        accessControl.grantInvestorRole(investor1);
        
        // Expect event emission for revocation
        vm.expectEmit(true, true, false, true);
        emit InvestorRoleRevoked(investor1, platformAdmin);
        
        // Revoke the role
        accessControl.revokeInvestorRole(investor1);
        
        // Verify investor role revoked
        assertFalse(accessControl.isInvestor(investor1));
        assertEq(accessControl.getInvestorCount(), 0);
        
        vm.stopPrank();
    }

    // ================================
    // Platform Admin Transfer Tests
    // ================================
    
    function testTransferPlatformAdmin() public {
        vm.startPrank(platformAdmin);
        
        // The function will emit events in this order:
        // 1. DEFAULT_ADMIN_ROLE revoked from old admin
        // 2. DEFAULT_ADMIN_ROLE granted to new admin  
        // 3. ADMIN_ROLE granted to new admin (if not already granted)
        // 4. AdminRoleGranted event
        // 5. PlatformAdminChanged event
        
        // We'll just check the final events we care about
        vm.expectEmit(true, true, false, true);
        emit AdminRoleGranted(admin1, platformAdmin);
        
        vm.expectEmit(true, true, false, true);
        emit PlatformAdminChanged(platformAdmin, admin1);
        
        accessControl.transferPlatformAdmin(admin1);
        
        // Verify platform admin changed
        assertEq(accessControl.platformAdmin(), admin1);
        
        // New admin should have DEFAULT_ADMIN_ROLE and ADMIN_ROLE
        assertTrue(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), admin1));
        assertTrue(accessControl.isAdmin(admin1));
        
        // Previous admin should not have DEFAULT_ADMIN_ROLE but might still have ADMIN_ROLE
        assertFalse(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), platformAdmin));
        
        vm.stopPrank();
    }

    function testTransferPlatformAdminUnauthorized() public {
        vm.startPrank(unauthorizedUser);
        
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address,bytes32)", unauthorizedUser, accessControl.DEFAULT_ADMIN_ROLE()));
        accessControl.transferPlatformAdmin(admin1);
        
        vm.stopPrank();
    }

    function testTransferPlatformAdminToZeroAddress() public {
        vm.startPrank(platformAdmin);
        
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        accessControl.transferPlatformAdmin(address(0));
        
        vm.stopPrank();
    }

    // ================================
    // Modifier Tests
    // ================================
    
    function testOnlyAdminModifier() public {
        // Grant exporter role to test user
        vm.prank(platformAdmin);
        accessControl.grantExporterRole(exporter1);
        
        // Test that non-admin cannot call admin function
        vm.startPrank(exporter1);
        vm.expectRevert(abi.encodeWithSignature("NotAdmin(address)", exporter1));
        accessControl.grantInvestorRole(investor1);
        vm.stopPrank();
        
        // Test that admin can call admin function
        vm.startPrank(platformAdmin);
        accessControl.grantInvestorRole(investor1);
        assertTrue(accessControl.isInvestor(investor1));
        vm.stopPrank();
    }

    // ================================
    // View Function Tests
    // ================================
    
    function testHasAnyRole() public {
        // User with no roles
        assertFalse(accessControl.hasAnyRole(unauthorizedUser));
        
        // Platform admin has roles
        assertTrue(accessControl.hasAnyRole(platformAdmin));
        
        vm.startPrank(platformAdmin);
        
        // Grant roles and test
        accessControl.grantExporterRole(exporter1);
        assertTrue(accessControl.hasAnyRole(exporter1));
        
        accessControl.grantInvestorRole(investor1);
        assertTrue(accessControl.hasAnyRole(investor1));
        
        vm.stopPrank();
    }

    function testGetUserRoles() public {
        vm.startPrank(platformAdmin);
        
        // Test user with no roles
        (bool hasAdminRole, bool hasExporterRole, bool hasInvestorRole) = accessControl.getUserRoles(unauthorizedUser);
        assertFalse(hasAdminRole);
        assertFalse(hasExporterRole);
        assertFalse(hasInvestorRole);
        
        // Grant multiple roles to a user
        accessControl.grantAdminRole(admin1);
        accessControl.grantExporterRole(admin1);
        
        (hasAdminRole, hasExporterRole, hasInvestorRole) = accessControl.getUserRoles(admin1);
        assertTrue(hasAdminRole);
        assertTrue(hasExporterRole);
        assertFalse(hasInvestorRole);
        
        vm.stopPrank();
    }

    // ================================
    // Edge Cases and Security Tests
    // ================================
    
    function testMultipleRolesSameUser() public {
        vm.startPrank(platformAdmin);
        
        // User can have multiple roles
        accessControl.grantAdminRole(admin1);
        accessControl.grantExporterRole(admin1);
        accessControl.grantInvestorRole(admin1);
        
        assertTrue(accessControl.isAdmin(admin1));
        assertTrue(accessControl.isExporter(admin1));
        assertTrue(accessControl.isInvestor(admin1));
        
        vm.stopPrank();
    }

    function testRoleCountsWithMultipleUsers() public {
        vm.startPrank(platformAdmin);
        
        // Grant roles to multiple users
        accessControl.grantAdminRole(admin1);
        accessControl.grantAdminRole(admin2);
        
        accessControl.grantExporterRole(exporter1);
        accessControl.grantExporterRole(exporter2);
        accessControl.grantExporterRole(admin1); // Admin can also be exporter
        
        accessControl.grantInvestorRole(investor1);
        accessControl.grantInvestorRole(investor2);
        
        // Check counts
        assertEq(accessControl.getAdminCount(), 3); // platformAdmin + admin1 + admin2
        assertEq(accessControl.getExporterCount(), 3); // exporter1 + exporter2 + admin1
        assertEq(accessControl.getInvestorCount(), 2); // investor1 + investor2
        
        vm.stopPrank();
    }

    function testZeroAddressValidation() public {
        vm.startPrank(platformAdmin);
        
        // All role granting functions should revert with zero address
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        accessControl.grantAdminRole(address(0));
        
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        accessControl.grantExporterRole(address(0));
        
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        accessControl.grantInvestorRole(address(0));
        
        // Revoke functions should also validate
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        accessControl.revokeAdminRole(address(0));
        
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        accessControl.revokeExporterRole(address(0));
        
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress(address)", address(0)));
        accessControl.revokeInvestorRole(address(0));
        
        vm.stopPrank();
    }

    // ================================
    // Integration Tests
    // ================================
    
    function testCompleteWorkflow() public {
        // Platform admin sets up initial roles
        vm.startPrank(platformAdmin);
        
        // Grant admin role to admin1
        accessControl.grantAdminRole(admin1);
        
        // Grant exporter role to exporter1
        accessControl.grantExporterRole(exporter1);
        
        // Grant investor role to investor1
        accessControl.grantInvestorRole(investor1);
        
        vm.stopPrank();
        
        // Admin1 should be able to manage roles
        vm.startPrank(admin1);
        
        accessControl.grantExporterRole(exporter2);
        accessControl.grantInvestorRole(investor2);
        
        assertTrue(accessControl.isExporter(exporter2));
        assertTrue(accessControl.isInvestor(investor2));
        
        vm.stopPrank();
        
        // Verify final state
        assertEq(accessControl.getAdminCount(), 2); // platformAdmin + admin1
        assertEq(accessControl.getExporterCount(), 2); // exporter1 + exporter2
        assertEq(accessControl.getInvestorCount(), 2); // investor1 + investor2
    }

    // ================================
    // Gas Usage Tests
    // ================================
    
    function testGasUsageRoleOperations() public {
        vm.startPrank(platformAdmin);
        
        // Measure gas for role granting
        uint256 gasBefore = gasleft();
        accessControl.grantAdminRole(admin1);
        uint256 gasAfter = gasleft();
        uint256 gasUsedGrantAdmin = gasBefore - gasAfter;
        
        gasBefore = gasleft();
        accessControl.grantExporterRole(exporter1);
        gasAfter = gasleft();
        uint256 gasUsedGrantExporter = gasBefore - gasAfter;
        
        // Log gas usage for analysis
        console.log("Gas used for grantAdminRole:", gasUsedGrantAdmin);
        console.log("Gas used for grantExporterRole:", gasUsedGrantExporter);
        
        // Gas usage should be reasonable (less than 125k gas for role operations)
        // Note: OpenZeppelin AccessControlEnumerable has higher gas costs due to enumeration
        assertLt(gasUsedGrantAdmin, 125000);
        assertLt(gasUsedGrantExporter, 125000);
        
        vm.stopPrank();
    }
}