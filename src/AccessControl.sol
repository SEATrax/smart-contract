// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

/**
 * @title PlatformAccessControl
 * @notice Role-based access control for the Shipping Invoice Funding Platform
 * @dev Defines and manages three primary roles: Admin, Exporter, and Investor
 * @dev Gas optimized: Uses custom errors, efficient modifiers, and minimal storage
 */
contract PlatformAccessControl is AccessControlEnumerable {
    // ================================
    // Role Definitions (Gas Optimized)
    // ================================
    
    /// @notice Admin role - can manage pools, allocate funds, trigger settlements
    /// @dev Using keccak256 for gas-efficient role constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Exporter role - can submit invoices and withdraw funds
    bytes32 public constant EXPORTER_ROLE = keccak256("EXPORTER_ROLE");
    
    /// @notice Investor role - can invest in pools and claim profits
    bytes32 public constant INVESTOR_ROLE = keccak256("INVESTOR_ROLE");

    // ================================
    // Custom Errors
    // ================================
    
    error NotAdmin(address caller);
    error NotExporter(address caller);
    error NotInvestor(address caller);
    error NotAuthorized(address caller, bytes32 role);
    error InvalidAddress(address addr);
    error RoleAlreadyAssigned(address account, bytes32 role);
    error RoleNotAssigned(address account, bytes32 role);

    // ================================
    // Events
    // ================================
    
    event AdminRoleGranted(address indexed account, address indexed grantor);
    event AdminRoleRevoked(address indexed account, address indexed revoker);
    event ExporterRoleGranted(address indexed account, address indexed grantor);
    event ExporterRoleRevoked(address indexed account, address indexed revoker);
    event InvestorRoleGranted(address indexed account, address indexed grantor);
    event InvestorRoleRevoked(address indexed account, address indexed revoker);
    event PlatformAdminChanged(address indexed previousAdmin, address indexed newAdmin);

    // ================================
    // State Variables
    // ================================
    
    /// @notice Platform admin who can grant initial roles
    address public platformAdmin;

    // ================================
    // Modifiers
    // ================================
    
    /// @notice Modifier to check if caller has admin role
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    /// @notice Modifier to check if caller has exporter role
    modifier onlyExporter() {
        _onlyExporter();
        _;
    }

    /// @notice Modifier to check if caller has investor role
    modifier onlyInvestor() {
        _onlyInvestor();
        _;
    }

    /// @notice Modifier to check if caller has admin or exporter role
    modifier onlyAdminOrExporter() {
        _onlyAdminOrExporter();
        _;
    }

    /// @notice Modifier to check if caller has admin or investor role
    modifier onlyAdminOrInvestor() {
        _onlyAdminOrInvestor();
        _;
    }

    /// @notice Modifier to validate address is not zero
    modifier validAddress(address addr) {
        _validAddress(addr);
        _;
    }

    // ================================
    // Internal Functions for Modifiers
    // ================================
    
    /// @notice Internal function for admin role check
    function _onlyAdmin() internal view {
        if (!hasRole(ADMIN_ROLE, _msgSender())) {
            revert NotAdmin(_msgSender());
        }
    }

    /// @notice Internal function for exporter role check
    function _onlyExporter() internal view {
        if (!hasRole(EXPORTER_ROLE, _msgSender())) {
            revert NotExporter(_msgSender());
        }
    }

    /// @notice Internal function for investor role check
    function _onlyInvestor() internal view {
        if (!hasRole(INVESTOR_ROLE, _msgSender())) {
            revert NotInvestor(_msgSender());
        }
    }

    /// @notice Internal function for admin or exporter role check
    function _onlyAdminOrExporter() internal view {
        address caller = _msgSender();
        if (!hasRole(ADMIN_ROLE, caller) && !hasRole(EXPORTER_ROLE, caller)) {
            revert NotAuthorized(caller, EXPORTER_ROLE);
        }
    }

    /// @notice Internal function for admin or investor role check
    function _onlyAdminOrInvestor() internal view {
        address caller = _msgSender();
        if (!hasRole(ADMIN_ROLE, caller) && !hasRole(INVESTOR_ROLE, caller)) {
            revert NotAuthorized(caller, INVESTOR_ROLE);
        }
    }

    /// @notice Internal function for address validation
    function _validAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert InvalidAddress(addr);
        }
    }

    // ================================
    // Constructor
    // ================================
    
    /**
     * @notice Initialize the access control with the deployer as platform admin
     * @param initialAdmin Address that will be granted initial admin role
     */
    constructor(address initialAdmin) validAddress(initialAdmin) {
        platformAdmin = initialAdmin;
        
        // Grant the default admin role to the platform admin
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(ADMIN_ROLE, initialAdmin);
        
        emit PlatformAdminChanged(address(0), initialAdmin);
        emit AdminRoleGranted(initialAdmin, initialAdmin);
    }

    // ================================
    // Admin Management Functions
    // ================================
    
    /**
     * @notice Grant admin role to an address
     * @param account Address to grant admin role
     */
    function grantAdminRole(address account) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        validAddress(account) 
    {
        if (hasRole(ADMIN_ROLE, account)) {
            revert RoleAlreadyAssigned(account, ADMIN_ROLE);
        }
        
        _grantRole(ADMIN_ROLE, account);
        emit AdminRoleGranted(account, _msgSender());
    }

    /**
     * @notice Revoke admin role from an address
     * @param account Address to revoke admin role
     */
    function revokeAdminRole(address account) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        validAddress(account) 
    {
        if (!hasRole(ADMIN_ROLE, account)) {
            revert RoleNotAssigned(account, ADMIN_ROLE);
        }
        
        _revokeRole(ADMIN_ROLE, account);
        emit AdminRoleRevoked(account, _msgSender());
    }

    // ================================
    // Exporter Role Management
    // ================================
    
    /**
     * @notice Grant exporter role to an address
     * @param account Address to grant exporter role
     */
    function grantExporterRole(address account) 
        external 
        onlyAdmin 
        validAddress(account) 
    {
        if (hasRole(EXPORTER_ROLE, account)) {
            revert RoleAlreadyAssigned(account, EXPORTER_ROLE);
        }
        
        _grantRole(EXPORTER_ROLE, account);
        emit ExporterRoleGranted(account, _msgSender());
    }

    /**
     * @notice Revoke exporter role from an address
     * @param account Address to revoke exporter role
     */
    function revokeExporterRole(address account) 
        external 
        onlyAdmin 
        validAddress(account) 
    {
        if (!hasRole(EXPORTER_ROLE, account)) {
            revert RoleNotAssigned(account, EXPORTER_ROLE);
        }
        
        _revokeRole(EXPORTER_ROLE, account);
        emit ExporterRoleRevoked(account, _msgSender());
    }

    // ================================
    // Investor Role Management
    // ================================
    
    /**
     * @notice Grant investor role to an address
     * @param account Address to grant investor role
     */
    function grantInvestorRole(address account) 
        external 
        onlyAdmin 
        validAddress(account) 
    {
        if (hasRole(INVESTOR_ROLE, account)) {
            revert RoleAlreadyAssigned(account, INVESTOR_ROLE);
        }
        
        _grantRole(INVESTOR_ROLE, account);
        emit InvestorRoleGranted(account, _msgSender());
    }

    /**
     * @notice Revoke investor role from an address
     * @param account Address to revoke investor role
     */
    function revokeInvestorRole(address account) 
        external 
        onlyAdmin 
        validAddress(account) 
    {
        if (!hasRole(INVESTOR_ROLE, account)) {
            revert RoleNotAssigned(account, INVESTOR_ROLE);
        }
        
        _revokeRole(INVESTOR_ROLE, account);
        emit InvestorRoleRevoked(account, _msgSender());
    }

    // ================================
    // Platform Admin Management
    // ================================
    
    /**
     * @notice Transfer platform admin to a new address
     * @param newAdmin Address of the new platform admin
     */
    function transferPlatformAdmin(address newAdmin) 
        external 
        validAddress(newAdmin) 
    {
        if (_msgSender() != platformAdmin) {
            revert NotAuthorized(_msgSender(), DEFAULT_ADMIN_ROLE);
        }
        
        address previousAdmin = platformAdmin;
        platformAdmin = newAdmin;
        
        // Transfer the default admin role
        _revokeRole(DEFAULT_ADMIN_ROLE, previousAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        
        // Grant admin role to new platform admin if not already granted
        if (!hasRole(ADMIN_ROLE, newAdmin)) {
            _grantRole(ADMIN_ROLE, newAdmin);
            emit AdminRoleGranted(newAdmin, previousAdmin);
        }
        
        emit PlatformAdminChanged(previousAdmin, newAdmin);
    }

    // ================================
    // View Functions
    // ================================
    
    /**
     * @notice Check if an address has admin role
     * @param account Address to check
     * @return bool True if address has admin role
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @notice Check if an address has exporter role
     * @param account Address to check
     * @return bool True if address has exporter role
     */
    function isExporter(address account) external view returns (bool) {
        return hasRole(EXPORTER_ROLE, account);
    }

    /**
     * @notice Check if an address has investor role
     * @param account Address to check
     * @return bool True if address has investor role
     */
    function isInvestor(address account) external view returns (bool) {
        return hasRole(INVESTOR_ROLE, account);
    }

    /**
     * @notice Get the number of addresses with admin role
     * @return uint256 Number of admins
     */
    function getAdminCount() external view returns (uint256) {
        return getRoleMemberCount(ADMIN_ROLE);
    }

    /**
     * @notice Get the number of addresses with exporter role
     * @return uint256 Number of exporters
     */
    function getExporterCount() external view returns (uint256) {
        return getRoleMemberCount(EXPORTER_ROLE);
    }

    /**
     * @notice Get the number of addresses with investor role
     * @return uint256 Number of investors
     */
    function getInvestorCount() external view returns (uint256) {
        return getRoleMemberCount(INVESTOR_ROLE);
    }

    /**
     * @notice Get admin address by index
     * @param index Index of the admin
     * @return address Admin address at the given index
     */
    function getAdminByIndex(uint256 index) external view returns (address) {
        return getRoleMember(ADMIN_ROLE, index);
    }

    /**
     * @notice Get exporter address by index
     * @param index Index of the exporter
     * @return address Exporter address at the given index
     */
    function getExporterByIndex(uint256 index) external view returns (address) {
        return getRoleMember(EXPORTER_ROLE, index);
    }

    /**
     * @notice Get investor address by index
     * @param index Index of the investor
     * @return address Investor address at the given index
     */
    function getInvestorByIndex(uint256 index) external view returns (address) {
        return getRoleMember(INVESTOR_ROLE, index);
    }

    // ================================
    // Utility Functions
    // ================================
    
    /**
     * @notice Check if an address has any role in the platform
     * @param account Address to check
     * @return bool True if address has any role
     */
    function hasAnyRole(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account) || 
               hasRole(EXPORTER_ROLE, account) || 
               hasRole(INVESTOR_ROLE, account);
    }

    /**
     * @notice Get all roles for an address
     * @param account Address to check
     * @return hasAdminRole True if has admin role
     * @return hasExporterRole True if has exporter role
     * @return hasInvestorRole True if has investor role
     */
    function getUserRoles(address account) 
        external 
        view 
        returns (
            bool hasAdminRole,
            bool hasExporterRole,
            bool hasInvestorRole
        ) 
    {
        hasAdminRole = hasRole(ADMIN_ROLE, account);
        hasExporterRole = hasRole(EXPORTER_ROLE, account);
        hasInvestorRole = hasRole(INVESTOR_ROLE, account);
    }
}