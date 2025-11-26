// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PlatformAccessControl} from "./AccessControl.sol";
import {InvoiceNFT} from "./InvoiceNFT.sol";
import {PoolNFT} from "./PoolNFT.sol";
import {PoolFundingManager} from "./PoolFundingManager.sol";

/**
 * @title PaymentOracle
 * @notice Oracle system for confirming invoice payments and triggering pool settlements
 * @dev Handles payment confirmations from trusted sources and automated settlement logic
 * 
 * Key Features:
 * - Payment confirmation from authorized oracles
 * - Automated pool settlement when all invoices are paid
 * - Manual fallback mechanisms for payment disputes
 * - Integration with existing contract ecosystem
 * 
 * @author SEATrax Team
 */
contract PaymentOracle {
    // ================================
    // State Variables
    // ================================

    /// @notice Reference to the platform access control contract
    PlatformAccessControl public immutable ACCESS_CONTROL;
    
    /// @notice Reference to the invoice NFT contract
    InvoiceNFT public immutable INVOICE_NFT;
    
    /// @notice Reference to the pool NFT contract
    PoolNFT public immutable POOL_NFT;
    
    /// @notice Reference to the pool funding manager contract
    PoolFundingManager public immutable POOL_FUNDING_MANAGER;

    // ================================
    // Oracle Configuration
    // ================================

    /// @notice Mapping of authorized oracle addresses
    mapping(address => bool) public authorizedOracles;
    
    /// @notice Payment confirmations for invoices
    /// @dev invoiceId => paymentHash => confirmed
    mapping(uint256 => mapping(bytes32 => bool)) public paymentConfirmations;
    
    /// @notice Number of confirmations required for payment finalization
    uint256 public constant REQUIRED_CONFIRMATIONS = 2;
    
    /// @notice Time window for payment confirmation (7 days)
    uint256 public constant CONFIRMATION_WINDOW = 7 days;
    
    /// @notice Grace period for manual intervention (2 days)
    uint256 public constant GRACE_PERIOD = 2 days;

    // ================================
    // Payment Tracking
    // ================================

    /// @notice Payment details for invoices
    struct PaymentRecord {
        uint256 amountPaid;           // Amount paid for the invoice
        uint256 paymentTimestamp;     // When payment was confirmed
        bytes32 paymentHash;          // Hash of payment transaction/proof
        uint256 confirmationCount;    // Number of oracle confirmations
        bool isConfirmed;             // Whether payment is fully confirmed
        bool isDisputed;              // Whether payment is under dispute
        uint256 disputeDeadline;      // Deadline for dispute resolution
    }
    
    /// @notice Payment records by invoice ID
    mapping(uint256 => PaymentRecord) public paymentRecords;
    
    /// @notice Pools pending settlement (all invoices paid)
    mapping(uint256 => bool) public poolsPendingSettlement;

    // ================================
    // Events
    // ================================

    event OracleAuthorized(address indexed oracle, address indexed authorizer);
    event OracleRevoked(address indexed oracle, address indexed revoker);
    
    event PaymentSubmitted(
        uint256 indexed invoiceId,
        bytes32 indexed paymentHash,
        uint256 amount,
        address indexed oracle
    );
    
    event PaymentConfirmed(
        uint256 indexed invoiceId,
        bytes32 indexed paymentHash,
        uint256 amount,
        uint256 timestamp
    );
    
    event PaymentDisputed(
        uint256 indexed invoiceId,
        bytes32 indexed paymentHash,
        address indexed disputer,
        uint256 disputeDeadline
    );
    
    event PaymentDisputeResolved(
        uint256 indexed invoiceId,
        bytes32 indexed paymentHash,
        bool paymentValid,
        address indexed resolver
    );
    
    event PoolSettlementTriggered(
        uint256 indexed poolId,
        uint256 totalPaid,
        uint256 timestamp
    );

    // ================================
    // Errors
    // ================================

    error ZeroAddress();
    error NotAuthorizedOracle(address oracle);
    error NotAdmin(address caller);
    error InvalidInvoiceId(uint256 invoiceId);
    error InvalidPoolId(uint256 poolId);
    error InvoiceNotFunded(uint256 invoiceId);
    error PaymentAlreadyConfirmed(uint256 invoiceId);
    error PaymentNotFound(uint256 invoiceId, bytes32 paymentHash);
    error InsufficientConfirmations(uint256 current, uint256 required);
    error PaymentAmountMismatch(uint256 expected, uint256 actual);
    error ConfirmationWindowExpired(uint256 deadline);
    error DisputeWindowExpired(uint256 deadline);
    error PoolNotReadyForSettlement(uint256 poolId);
    error PaymentUnderDispute(uint256 invoiceId);

    // ================================
    // Modifiers
    // ================================

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (!ACCESS_CONTROL.isAdmin(msg.sender)) {
            revert NotAdmin(msg.sender);
        }
    }

    modifier onlyAuthorizedOracle() {
        _onlyAuthorizedOracle();
        _;
    }

    function _onlyAuthorizedOracle() internal view {
        if (!authorizedOracles[msg.sender]) {
            revert NotAuthorizedOracle(msg.sender);
        }
    }

    modifier validInvoiceId(uint256 invoiceId) {
        _validInvoiceId(invoiceId);
        _;
    }

    function _validInvoiceId(uint256 invoiceId) internal view {
        if (invoiceId == 0 || invoiceId > INVOICE_NFT.totalSupply()) {
            revert InvalidInvoiceId(invoiceId);
        }
    }

    modifier validPoolId(uint256 poolId) {
        _validPoolId(poolId);
        _;
    }

    function _validPoolId(uint256 poolId) internal view {
        if (poolId == 0 || poolId > POOL_NFT.totalSupply()) {
            revert InvalidPoolId(poolId);
        }
    }

    // ================================
    // Constructor
    // ================================

    constructor(
        address accessControl,
        address invoiceNft,
        address poolNft,
        address poolFundingManager
    ) {
        if (accessControl == address(0)) revert ZeroAddress();
        if (invoiceNft == address(0)) revert ZeroAddress();
        if (poolNft == address(0)) revert ZeroAddress();
        if (poolFundingManager == address(0)) revert ZeroAddress();

        ACCESS_CONTROL = PlatformAccessControl(accessControl);
        INVOICE_NFT = InvoiceNFT(invoiceNft);
        POOL_NFT = PoolNFT(poolNft);
        POOL_FUNDING_MANAGER = PoolFundingManager(poolFundingManager);
    }

    // ================================
    // Oracle Management
    // ================================

    /**
     * @notice Authorize an oracle to submit payment confirmations
     * @param oracle Address of the oracle to authorize
     */
    function authorizeOracle(address oracle) external onlyAdmin {
        if (oracle == address(0)) revert ZeroAddress();
        
        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle, msg.sender);
    }

    /**
     * @notice Revoke oracle authorization
     * @param oracle Address of the oracle to revoke
     */
    function revokeOracle(address oracle) external onlyAdmin {
        authorizedOracles[oracle] = false;
        emit OracleRevoked(oracle, msg.sender);
    }

    // ================================
    // Payment Confirmation
    // ================================

    /**
     * @notice Submit payment confirmation for an invoice
     * @param invoiceId ID of the paid invoice
     * @param paymentHash Hash of the payment transaction/proof
     * @param amountPaid Amount paid for the invoice
     */
    function submitPaymentConfirmation(
        uint256 invoiceId,
        bytes32 paymentHash,
        uint256 amountPaid
    ) external onlyAuthorizedOracle validInvoiceId(invoiceId) {
        InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(invoiceId);
        
        // Validate invoice is funded and eligible for payment
        if (invoice.status != InvoiceNFT.InvoiceStatus.Funded) {
            revert InvoiceNotFunded(invoiceId);
        }
        
        // Validate payment amount matches shipping amount
        if (amountPaid != invoice.shippingAmount) {
            revert PaymentAmountMismatch(invoice.shippingAmount, amountPaid);
        }
        
        PaymentRecord storage record = paymentRecords[invoiceId];
        
        // Check if payment already confirmed
        if (record.isConfirmed) {
            revert PaymentAlreadyConfirmed(invoiceId);
        }
        
        // Initialize payment record if first confirmation
        if (record.paymentHash == bytes32(0)) {
            record.paymentHash = paymentHash;
            record.amountPaid = amountPaid;
            record.paymentTimestamp = block.timestamp;
            record.disputeDeadline = block.timestamp + CONFIRMATION_WINDOW + GRACE_PERIOD;
        }
        
        // Validate payment hash matches
        if (record.paymentHash != paymentHash) {
            revert PaymentNotFound(invoiceId, paymentHash);
        }
        
        // Check confirmation window hasn't expired
        if (block.timestamp > record.paymentTimestamp + CONFIRMATION_WINDOW) {
            revert ConfirmationWindowExpired(record.paymentTimestamp + CONFIRMATION_WINDOW);
        }
        
        // Record oracle confirmation
        if (!paymentConfirmations[invoiceId][paymentHash]) {
            paymentConfirmations[invoiceId][paymentHash] = true;
            record.confirmationCount++;
            
            emit PaymentSubmitted(invoiceId, paymentHash, amountPaid, msg.sender);
        }
        
        // Check if we have sufficient confirmations
        if (record.confirmationCount >= REQUIRED_CONFIRMATIONS) {
            _finalizePayment(invoiceId);
        }
    }

    /**
     * @notice Finalize payment after sufficient confirmations
     * @param invoiceId ID of the invoice to finalize payment
     */
    function _finalizePayment(uint256 invoiceId) internal {
        PaymentRecord storage record = paymentRecords[invoiceId];
        
        // Mark payment as confirmed
        record.isConfirmed = true;
        
        // Update invoice status to Paid
        INVOICE_NFT.markInvoicePaid(invoiceId, record.amountPaid);
        
        emit PaymentConfirmed(
            invoiceId, 
            record.paymentHash, 
            record.amountPaid, 
            block.timestamp
        );
        
        // Check if this completes any pools for settlement
        _checkPoolSettlement(invoiceId);
    }

    /**
     * @notice Check if invoice payment completes a pool for settlement
     * @param invoiceId ID of the paid invoice
     */
    function _checkPoolSettlement(uint256 invoiceId) internal {
        // Find pools containing this invoice
        uint256 poolCount = POOL_NFT.totalSupply();
        
        for (uint256 poolId = 1; poolId <= poolCount; poolId++) {
            PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
            
            // Skip if pool not in correct state
            if (pool.status != PoolNFT.PoolStatus.Funded) {
                continue;
            }
            
            // Check if this invoice is in the pool
            bool invoiceInPool = false;
            uint256[] memory invoiceIds = POOL_NFT.getPoolInvoices(poolId);
            
            for (uint256 i = 0; i < invoiceIds.length; i++) {
                if (invoiceIds[i] == invoiceId) {
                    invoiceInPool = true;
                    break;
                }
            }
            
            if (!invoiceInPool) {
                continue;
            }
            
            // Check if all invoices in pool are paid
            bool allInvoicesPaid = true;
            uint256 totalPaid = 0;
            
            for (uint256 i = 0; i < invoiceIds.length; i++) {
                InvoiceNFT.Invoice memory poolInvoice = INVOICE_NFT.getInvoice(invoiceIds[i]);
                
                if (poolInvoice.status != InvoiceNFT.InvoiceStatus.Paid) {
                    allInvoicesPaid = false;
                    break;
                }
                
                totalPaid += paymentRecords[invoiceIds[i]].amountPaid;
            }
            
            // Trigger settlement if all invoices paid
            if (allInvoicesPaid && !poolsPendingSettlement[poolId]) {
                poolsPendingSettlement[poolId] = true;
                
                // Mark pool as settling
                POOL_NFT.markPoolSettling(poolId);
                
                // Trigger profit distribution
                POOL_FUNDING_MANAGER.distributeProfits(poolId);
                
                emit PoolSettlementTriggered(poolId, totalPaid, block.timestamp);
            }
        }
    }

    // ================================
    // Dispute Management
    // ================================

    /**
     * @notice Dispute a payment confirmation
     * @param invoiceId ID of the invoice with disputed payment
     * @param paymentHash Hash of the disputed payment
     */
    function disputePayment(
        uint256 invoiceId,
        bytes32 paymentHash
    ) external onlyAdmin validInvoiceId(invoiceId) {
        PaymentRecord storage record = paymentRecords[invoiceId];
        
        if (record.paymentHash != paymentHash) {
            revert PaymentNotFound(invoiceId, paymentHash);
        }
        
        if (block.timestamp > record.disputeDeadline) {
            revert DisputeWindowExpired(record.disputeDeadline);
        }
        
        record.isDisputed = true;
        
        emit PaymentDisputed(
            invoiceId, 
            paymentHash, 
            msg.sender, 
            record.disputeDeadline
        );
    }

    /**
     * @notice Resolve payment dispute (admin only)
     * @param invoiceId ID of the invoice with disputed payment
     * @param paymentValid Whether the payment is valid
     */
    function resolvePaymentDispute(
        uint256 invoiceId,
        bool paymentValid
    ) external onlyAdmin validInvoiceId(invoiceId) {
        PaymentRecord storage record = paymentRecords[invoiceId];
        
        if (!record.isDisputed) {
            revert PaymentNotFound(invoiceId, record.paymentHash);
        }
        
        record.isDisputed = false;
        
        if (paymentValid && !record.isConfirmed) {
            _finalizePayment(invoiceId);
        } else if (!paymentValid) {
            // Reset payment record for resubmission
            delete paymentRecords[invoiceId];
        }
        
        emit PaymentDisputeResolved(
            invoiceId, 
            record.paymentHash, 
            paymentValid, 
            msg.sender
        );
    }

    // ================================
    // Manual Settlement Functions
    // ================================

    /**
     * @notice Manually trigger pool settlement (admin only)
     * @param poolId ID of the pool to settle
     */
    function manualSettlement(uint256 poolId) external onlyAdmin validPoolId(poolId) {
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        
        if (pool.status != PoolNFT.PoolStatus.Funded) {
            revert PoolNotReadyForSettlement(poolId);
        }
        
        // Verify all invoices are paid
        uint256[] memory invoiceIds = POOL_NFT.getPoolInvoices(poolId);
        uint256 totalPaid = 0;
        
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(invoiceIds[i]);
            
            if (invoice.status != InvoiceNFT.InvoiceStatus.Paid) {
                revert PoolNotReadyForSettlement(poolId);
            }
            
            totalPaid += paymentRecords[invoiceIds[i]].amountPaid;
        }
        
        poolsPendingSettlement[poolId] = true;
        
        // Mark pool as settling
        POOL_NFT.markPoolSettling(poolId);
        
        // Trigger profit distribution
        POOL_FUNDING_MANAGER.distributeProfits(poolId);
        
        emit PoolSettlementTriggered(poolId, totalPaid, block.timestamp);
    }

    // ================================
    // View Functions
    // ================================

    /**
     * @notice Get payment record for an invoice
     * @param invoiceId ID of the invoice
     * @return Payment record details
     */
    function getPaymentRecord(uint256 invoiceId) 
        external 
        view 
        validInvoiceId(invoiceId)
        returns (PaymentRecord memory) 
    {
        return paymentRecords[invoiceId];
    }

    /**
     * @notice Check if oracle is authorized
     * @param oracle Address to check
     * @return True if oracle is authorized
     */
    function isAuthorizedOracle(address oracle) external view returns (bool) {
        return authorizedOracles[oracle];
    }

    /**
     * @notice Get payment confirmation status
     * @param invoiceId ID of the invoice
     * @param paymentHash Hash of the payment
     * @return True if payment is confirmed by oracle
     */
    function isPaymentConfirmed(
        uint256 invoiceId, 
        bytes32 paymentHash
    ) external view returns (bool) {
        return paymentConfirmations[invoiceId][paymentHash];
    }
}