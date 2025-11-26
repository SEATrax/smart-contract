// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {PlatformAccessControl} from "./AccessControl.sol";

/**
 * @title InvoiceNFT
 * @notice ERC-721 contract representing shipping invoices for the funding platform
 * @dev Each NFT represents a single shipping invoice with loan request and payment tracking
 * @dev Gas optimized with packed structs and efficient storage patterns
 */
contract InvoiceNFT is ERC721Enumerable {
    // ================================
    // Constants (Gas Optimized)
    // ================================
    
    /// @notice Minimum funding threshold (70% in basis points)
    uint256 public constant MIN_FUND_RATIO = 7000; // 70%
    
    /// @notice Basis points denominator (100%)
    uint256 public constant BASIS_POINTS = 10000;

    // ================================
    // Custom Errors (Gas Efficient)
    // ================================
    
    error NotAuthorized(address caller);
    error NotExporter(address caller);
    error NotAdmin(address caller);
    error InvalidInvoiceId(uint256 invoiceId);
    error InvalidAmount(uint256 amount);
    error InvalidStatus(InvoiceStatus current, InvoiceStatus required);
    error InsufficientFunding(uint256 available, uint256 required);
    error WithdrawalExceedsAvailable(uint256 requested, uint256 available);
    error InvoiceAlreadyFinalized(uint256 invoiceId);
    error InvalidAddress(address addr);
    error InvalidShippingDate(uint256 shippingDate);

    // ================================
    // Enums
    // ================================
    
    /// @notice Invoice status enumeration
    enum InvoiceStatus {
        Pending,     // Initial state, not yet finalized
        Finalized,   // Ready for funding
        Fundraising, // Being funded through pools
        Funded,      // Minimum threshold reached, can withdraw
        Paid,        // Importer has paid, ready for settlement
        Cancelled    // Invoice cancelled
    }

    // ================================
    // Structs (Gas Optimized Storage)
    // ================================
    
    /// @notice Invoice metadata structure
    /// @dev Optimized for storage slots to minimize gas costs
    struct Invoice {
        // Slot 1 (32 bytes)
        address exporterWallet;     // 20 bytes - Exporter's wallet address
        InvoiceStatus status;       // 1 byte - Current status
        uint88 shippingAmount;      // 11 bytes - Total shipping amount (supports up to ~$3M with 18 decimals)
        
        // Slot 2 (32 bytes)  
        uint128 loanAmount;         // 16 bytes - Requested loan amount (supports up to ~$340M with 18 decimals)
        uint128 amountInvested;     // 16 bytes - Total amount invested from pools
        
        // Slot 3 (32 bytes)
        uint128 amountWithdrawn;    // 16 bytes - Amount withdrawn by exporter
        uint64 shippingDate;        // 8 bytes - Unix timestamp of shipping date
        uint64 createdAt;           // 8 bytes - Creation timestamp
        
        // Dynamic fields (separate storage slots)
        string exporterCompany;     // Company name
        string importerCompany;     // Importer company name
    }

    // ================================
    // State Variables
    // ================================
    
    /// @notice Access control contract
    PlatformAccessControl public immutable ACCESS_CONTROL;
    
    /// @notice Invoice data mapping
    mapping(uint256 => Invoice) private _invoices;
    
    /// @notice Next token ID counter
    uint256 private _nextTokenId = 1;
    
    /// @notice Total loan amount across all invoices
    uint256 public totalLoanAmount;
    
    /// @notice Total invested amount across all invoices
    uint256 public totalInvestedAmount;

    // ================================
    // Events
    // ================================
    
    event InvoiceMinted(
        uint256 indexed invoiceId,
        address indexed exporter,
        string exporterCompany,
        string importerCompany,
        uint256 shippingAmount,
        uint256 loanAmount,
        uint256 shippingDate
    );
    
    event InvoiceStatusUpdated(
        uint256 indexed invoiceId,
        InvoiceStatus previousStatus,
        InvoiceStatus newStatus
    );
    
    event InvoiceWithdrawal(
        uint256 indexed invoiceId,
        address indexed exporter,
        uint256 amount,
        uint256 remainingAvailable
    );
    
    event InvoiceFunded(
        uint256 indexed invoiceId,
        uint256 amount,
        uint256 totalInvested
    );
    
    event InvoicePaymentConfirmed(
        uint256 indexed invoiceId,
        address indexed confirmedBy
    );

    // ================================
    // Modifiers
    // ================================
    
    /// @notice Only admin modifier
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    /// @notice Only admin internal check
    function _onlyAdmin() internal view {
        if (!ACCESS_CONTROL.isAdmin(msg.sender)) {
            revert NotAdmin(msg.sender);
        }
    }
    
    /// @notice Only exporter modifier  
    modifier onlyExporter() {
        _onlyExporter();
        _;
    }

    /// @notice Only exporter internal check
    function _onlyExporter() internal view {
        if (!ACCESS_CONTROL.isExporter(msg.sender)) {
            revert NotExporter(msg.sender);
        }
    }
    
    /// @notice Only invoice owner modifier
    modifier onlyInvoiceOwner(uint256 invoiceId) {
        _onlyInvoiceOwner(invoiceId);
        _;
    }

    /// @notice Only invoice owner internal check
    function _onlyInvoiceOwner(uint256 invoiceId) internal view {
        if (ownerOf(invoiceId) != msg.sender) {
            revert NotAuthorized(msg.sender);
        }
    }
    
    /// @notice Valid invoice ID modifier
    modifier validInvoiceId(uint256 invoiceId) {
        _validInvoiceId(invoiceId);
        _;
    }

    /// @notice Valid invoice ID internal check
    function _validInvoiceId(uint256 invoiceId) internal view {
        if (invoiceId == 0 || invoiceId >= _nextTokenId || _ownerOf(invoiceId) == address(0)) {
            revert InvalidInvoiceId(invoiceId);
        }
    }
    
    /// @notice Valid address modifier
    modifier validAddress(address addr) {
        _validAddress(addr);
        _;
    }

    /// @notice Valid address internal check
    function _validAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert InvalidAddress(addr);
        }
    }

    // ================================
    // Constructor
    // ================================
    
    /**
     * @notice Initialize the Invoice NFT contract
     * @param accessControlAddress Address of the access control contract
     */
    constructor(address accessControlAddress) 
        ERC721("Shipping Invoice NFT", "INVOICE")
        validAddress(accessControlAddress)
    {
        ACCESS_CONTROL = PlatformAccessControl(accessControlAddress);
    }

    // ================================
    // Invoice Creation Functions
    // ================================
    
    /**
     * @notice Create and mint a new invoice NFT
     * @param exporterCompany Name of the exporter company
     * @param importerCompany Name of the importer company
     * @param shippingAmount Total shipping/invoice amount
     * @param loanAmount Requested loan amount (must be <= shipping amount)
     * @param shippingDate Unix timestamp of shipping date
     * @return invoiceId The minted invoice NFT ID
     */
    function mintInvoice(
        string calldata exporterCompany,
        string calldata importerCompany,
        uint256 shippingAmount,
        uint256 loanAmount,
        uint256 shippingDate
    ) external onlyExporter returns (uint256 invoiceId) {
        // Validation
        if (shippingAmount == 0) revert InvalidAmount(shippingAmount);
        if (loanAmount == 0) revert InvalidAmount(loanAmount);
        if (loanAmount > shippingAmount) revert InvalidAmount(loanAmount);
        if (shippingDate == 0) revert InvalidShippingDate(shippingDate);
        if (bytes(exporterCompany).length == 0) revert InvalidAddress(address(0));
        if (bytes(importerCompany).length == 0) revert InvalidAddress(address(0));
        
        // Check amount limits to fit in storage slots
        if (shippingAmount > type(uint88).max) revert InvalidAmount(shippingAmount);
        if (loanAmount > type(uint128).max) revert InvalidAmount(loanAmount);
        if (shippingDate > type(uint64).max) revert InvalidShippingDate(shippingDate);
        
        // Get next token ID
        invoiceId = _nextTokenId;
        unchecked {
            ++_nextTokenId;
        }
        
        // Create invoice struct
        _invoices[invoiceId] = Invoice({
            exporterWallet: msg.sender,
            status: InvoiceStatus.Pending,
            // casting to 'uint88' is safe because we validated shippingAmount <= type(uint88).max
            // forge-lint: disable-next-line(unsafe-typecast)
            shippingAmount: uint88(shippingAmount),
            // casting to 'uint128' is safe because we validated loanAmount <= type(uint128).max
            // forge-lint: disable-next-line(unsafe-typecast)
            loanAmount: uint128(loanAmount),
            amountInvested: 0,
            amountWithdrawn: 0,
            // casting to 'uint64' is safe because we validated shippingDate <= type(uint64).max
            // forge-lint: disable-next-line(unsafe-typecast)
            shippingDate: uint64(shippingDate),
            createdAt: uint64(block.timestamp),
            exporterCompany: exporterCompany,
            importerCompany: importerCompany
        });
        
        // Update totals
        unchecked {
            totalLoanAmount += loanAmount;
        }
        
        // Mint NFT to exporter
        _mint(msg.sender, invoiceId);
        
        emit InvoiceMinted(
            invoiceId,
            msg.sender,
            exporterCompany,
            importerCompany,
            shippingAmount,
            loanAmount,
            shippingDate
        );
    }

    // ================================
    // Invoice Management Functions
    // ================================
    
    /**
     * @notice Finalize an invoice to make it ready for funding
     * @param invoiceId The invoice ID to finalize
     */
    function finalizeInvoice(uint256 invoiceId) 
        external 
        onlyInvoiceOwner(invoiceId)
        validInvoiceId(invoiceId)
    {
        Invoice storage invoice = _invoices[invoiceId];
        
        if (invoice.status != InvoiceStatus.Pending) {
            revert InvalidStatus(invoice.status, InvoiceStatus.Pending);
        }
        
        // Update status to finalized
        InvoiceStatus previousStatus = invoice.status;
        invoice.status = InvoiceStatus.Finalized;
        
        emit InvoiceStatusUpdated(invoiceId, previousStatus, InvoiceStatus.Finalized);
    }
    
    /**
     * @notice Cancel a pending invoice
     * @param invoiceId The invoice ID to cancel
     */
    function cancelInvoice(uint256 invoiceId)
        external
        onlyInvoiceOwner(invoiceId)
        validInvoiceId(invoiceId)
    {
        Invoice storage invoice = _invoices[invoiceId];
        
        if (invoice.status != InvoiceStatus.Pending) {
            revert InvalidStatus(invoice.status, InvoiceStatus.Pending);
        }
        
        // Update status to cancelled
        InvoiceStatus previousStatus = invoice.status;
        invoice.status = InvoiceStatus.Cancelled;
        
        // Remove from total loan amount
        unchecked {
            totalLoanAmount -= invoice.loanAmount;
        }
        
        emit InvoiceStatusUpdated(invoiceId, previousStatus, InvoiceStatus.Cancelled);
    }

    // ================================
    // Pool Integration Functions (Called by Pool Contracts)
    // ================================
    
    /**
     * @notice Add funding to an invoice (called by pool contracts)
     * @param invoiceId The invoice ID to fund
     * @param amount The amount to add
     */
    function addFunding(uint256 invoiceId, uint256 amount) 
        external
        onlyAdmin
        validInvoiceId(invoiceId)
    {
        if (amount == 0) revert InvalidAmount(amount);
        
        Invoice storage invoice = _invoices[invoiceId];
        
        // Can only fund finalized invoices
        if (invoice.status != InvoiceStatus.Finalized && invoice.status != InvoiceStatus.Fundraising) {
            revert InvalidStatus(invoice.status, InvoiceStatus.Finalized);
        }
        
        // Check funding doesn't exceed loan amount
        if (invoice.amountInvested + amount > invoice.loanAmount) {
            revert InvalidAmount(amount);
        }
        
        // Update funding
        unchecked {
            // casting to 'uint128' is safe because we validated amount + amountInvested <= loanAmount <= type(uint128).max
            // forge-lint: disable-next-line(unsafe-typecast)
            invoice.amountInvested += uint128(amount);
            totalInvestedAmount += amount;
        }
        
        // Update status to fundraising if first funding
        if (invoice.status == InvoiceStatus.Finalized) {
            InvoiceStatus previousStatus = invoice.status;
            invoice.status = InvoiceStatus.Fundraising;
            emit InvoiceStatusUpdated(invoiceId, previousStatus, InvoiceStatus.Fundraising);
        }
        
        // Check if minimum funding threshold reached
        if (_isEligibleForWithdrawal(invoiceId)) {
            InvoiceStatus previousStatus = invoice.status;
            invoice.status = InvoiceStatus.Funded;
            emit InvoiceStatusUpdated(invoiceId, previousStatus, InvoiceStatus.Funded);
        }
        
        emit InvoiceFunded(invoiceId, amount, invoice.amountInvested);
    }

    // ================================
    // Withdrawal Functions
    // ================================
    
    /**
     * @notice Withdraw available funds from an invoice
     * @param invoiceId The invoice ID to withdraw from
     * @param amount The amount to withdraw (0 = withdraw all available)
     */
    function withdrawFunds(uint256 invoiceId, uint256 amount)
        external
        onlyInvoiceOwner(invoiceId)
        validInvoiceId(invoiceId)
    {
        Invoice storage invoice = _invoices[invoiceId];
        
        // Check invoice is eligible for withdrawal
        if (!_isEligibleForWithdrawal(invoiceId)) {
            uint256 required = (invoice.loanAmount * MIN_FUND_RATIO) / BASIS_POINTS;
            revert InsufficientFunding(invoice.amountInvested, required);
        }
        
        // Calculate available amount
        uint256 available = invoice.amountInvested - invoice.amountWithdrawn;
        
        // If amount is 0, withdraw all available
        if (amount == 0) {
            amount = available;
        }
        
        // Check sufficient funds available
        if (amount > available) {
            revert WithdrawalExceedsAvailable(amount, available);
        }
        
        // Update withdrawn amount
        unchecked {
            // casting to 'uint128' is safe because amount <= available <= amountInvested <= type(uint128).max
            // forge-lint: disable-next-line(unsafe-typecast)
            invoice.amountWithdrawn += uint128(amount);
        }
        
        // Transfer funds (this contract should hold the funds from pool investments)
        // In a real implementation, this would interact with the pool funding manager
        // For now, we emit an event that the pool manager will listen to
        
        uint256 remainingAvailable = available - amount;
        
        emit InvoiceWithdrawal(invoiceId, msg.sender, amount, remainingAvailable);
    }

    // ================================
    // Payment Confirmation Functions
    // ================================
    
    /**
     * @notice Mark an invoice as paid by importer
     * @param invoiceId The invoice ID to mark as paid
     */
    function confirmPayment(uint256 invoiceId)
        external
        onlyAdmin
        validInvoiceId(invoiceId)
    {
        Invoice storage invoice = _invoices[invoiceId];
        
        // Can only confirm payment for funded invoices
        if (invoice.status != InvoiceStatus.Funded && invoice.status != InvoiceStatus.Fundraising) {
            revert InvalidStatus(invoice.status, InvoiceStatus.Funded);
        }
        
        // Update status to paid
        InvoiceStatus previousStatus = invoice.status;
        invoice.status = InvoiceStatus.Paid;
        
        emit InvoiceStatusUpdated(invoiceId, previousStatus, InvoiceStatus.Paid);
        emit InvoicePaymentConfirmed(invoiceId, msg.sender);
    }

    // ================================
    // View Functions
    // ================================
    
    /**
     * @notice Get invoice details
     * @param invoiceId The invoice ID
     * @return invoice The complete invoice struct
     */
    function getInvoice(uint256 invoiceId) 
        external 
        view 
        validInvoiceId(invoiceId) 
        returns (Invoice memory invoice) 
    {
        return _invoices[invoiceId];
    }
    
    /**
     * @notice Check if invoice is eligible for withdrawal (70% funded)
     * @param invoiceId The invoice ID
     * @return eligible True if eligible for withdrawal
     */
    function isEligibleForWithdrawal(uint256 invoiceId) 
        external 
        view 
        validInvoiceId(invoiceId) 
        returns (bool eligible) 
    {
        return _isEligibleForWithdrawal(invoiceId);
    }
    
    /**
     * @notice Get available withdrawal amount for an invoice
     * @param invoiceId The invoice ID
     * @return available Available amount for withdrawal
     */
    function getAvailableWithdrawal(uint256 invoiceId)
        external
        view
        validInvoiceId(invoiceId)
        returns (uint256 available)
    {
        Invoice storage invoice = _invoices[invoiceId];
        
        if (!_isEligibleForWithdrawal(invoiceId)) {
            return 0;
        }
        
        return invoice.amountInvested - invoice.amountWithdrawn;
    }
    
    /**
     * @notice Get funding progress for an invoice
     * @param invoiceId The invoice ID
     * @return funded Amount funded so far
     * @return total Total loan amount requested
     * @return percentage Funding percentage in basis points
     */
    function getFundingProgress(uint256 invoiceId)
        external
        view
        validInvoiceId(invoiceId)
        returns (uint256 funded, uint256 total, uint256 percentage)
    {
        Invoice storage invoice = _invoices[invoiceId];
        funded = invoice.amountInvested;
        total = invoice.loanAmount;
        
        if (total == 0) {
            percentage = 0;
        } else {
            percentage = (funded * BASIS_POINTS) / total;
        }
    }
    
    /**
     * @notice Get invoices by status
     * @param status The status to filter by
     * @return invoiceIds Array of invoice IDs with the specified status
     */
    function getInvoicesByStatus(InvoiceStatus status)
        external
        view
        returns (uint256[] memory invoiceIds)
    {
        uint256 totalSupply = totalSupply();
        uint256[] memory temp = new uint256[](totalSupply);
        uint256 count = 0;
        
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 invoiceId = tokenByIndex(i);
            if (_invoices[invoiceId].status == status) {
                temp[count] = invoiceId;
                unchecked { ++count; }
            }
        }
        
        // Create result array with exact size
        invoiceIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            invoiceIds[i] = temp[i];
        }
    }
    
    /**
     * @notice Get invoices by exporter
     * @param exporter The exporter address
     * @return invoiceIds Array of invoice IDs owned by the exporter
     */
    function getInvoicesByExporter(address exporter)
        external
        view
        returns (uint256[] memory invoiceIds)
    {
        uint256 balance = balanceOf(exporter);
        invoiceIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            invoiceIds[i] = tokenOfOwnerByIndex(exporter, i);
        }
    }

    // ================================
    // Internal Functions
    // ================================
    
    /**
     * @notice Check if invoice is eligible for withdrawal (internal)
     * @param invoiceId The invoice ID
     * @return eligible True if eligible
     */
    function _isEligibleForWithdrawal(uint256 invoiceId) 
        internal 
        view 
        returns (bool eligible) 
    {
        Invoice storage invoice = _invoices[invoiceId];
        
        // Must be in funded or fundraising status with minimum funding
        if (invoice.status != InvoiceStatus.Fundraising && invoice.status != InvoiceStatus.Funded) {
            return false;
        }
        
        // Check 70% funding threshold
        uint256 minRequired = (invoice.loanAmount * MIN_FUND_RATIO) / BASIS_POINTS;
        return invoice.amountInvested >= minRequired;
    }

    // ================================
    // Utility Functions
    // ================================
    
    /**
     * @notice Get platform statistics
     * @return totalInvoices Total number of invoices minted
     * @return totalLoan Total loan amount across all invoices
     * @return totalInvested Total amount invested across all invoices
     */
    function getPlatformStats() 
        external 
        view 
        returns (
            uint256 totalInvoices,
            uint256 totalLoan,
            uint256 totalInvested
        ) 
    {
        totalInvoices = totalSupply();
        totalLoan = totalLoanAmount;
        totalInvested = totalInvestedAmount;
    }
}