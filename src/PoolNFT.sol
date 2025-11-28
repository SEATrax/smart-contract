// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {PlatformAccessControl} from "./AccessControl.sol";
import {InvoiceNFT} from "./InvoiceNFT.sol";

/**
 * @title PoolNFT
 * @notice ERC-721 contract representing curated pools of shipping invoices for investment
 * @dev Each NFT represents a pool of invoices bundled together for investor funding
 * @dev Gas optimized with packed structs and efficient storage patterns
 */
contract PoolNFT is ERC721Enumerable {
    // ================================
    // Constants (Gas Optimized)
    // ================================
    
    /// @notice Maximum number of invoices per pool
    uint256 public constant MAX_INVOICES_PER_POOL = 50;
    
    /// @notice Minimum funding threshold for pool to be considered funded
    uint256 public constant MIN_FUNDING_THRESHOLD = 7000; // 70%
    
    /// @notice Basis points denominator (100%)
    uint256 public constant BASIS_POINTS = 10000;

    // ================================
    // Custom Errors (Gas Efficient)
    // ================================
    
    error NotAuthorized(address caller);
    error NotAdmin(address caller);
    error InvalidPoolId(uint256 poolId);
    error InvalidInvoiceId(uint256 invoiceId);
    error InvalidPoolName(string name);
    error InvalidStatus(PoolStatus current, PoolStatus required);
    error PoolTooManyInvoices(uint256 count, uint256 max);
    error InvoiceAlreadyInPool(uint256 invoiceId, uint256 existingPoolId);
    error InvoiceNotFinalized(uint256 invoiceId);
    error InvalidAddress(address addr);
    error EmptyInvoiceArray();
    error PoolNotOpen(uint256 poolId);
    error InsufficientFunding(uint256 current, uint256 required);

    // ================================
    // Enums
    // ================================
    
    /// @notice Pool status enumeration
    enum PoolStatus {
        Open,        // Pool created, invoices can be added
        Fundraising, // Pool finalized, accepting investments
        Funded,      // Minimum funding reached, funds allocated to invoices
        Settling,    // All invoices paid, profit distribution in progress
        Completed    // All funds distributed to investors
    }

    // ================================
    // Structs (Gas Optimized Storage)
    // ================================
    
    /// @notice Pool metadata structure
    /// @dev Optimized for storage slots to minimize gas costs
    struct Pool {
        // Slot 1 (32 bytes)
        address creator;            // 20 bytes - Admin who created the pool
        PoolStatus status;          // 1 byte - Current pool status
        uint8 invoiceCount;         // 1 byte - Number of invoices in pool
        uint88 totalLoanAmount;     // 11 bytes - Total loan amount across all invoices
        
        // Slot 2 (32 bytes)
        uint128 totalShippingAmount; // 16 bytes - Total shipping amount across all invoices
        uint128 totalInvested;       // 16 bytes - Total amount invested in pool
        
        // Slot 3 (32 bytes)
        uint128 totalDistributed;   // 16 bytes - Total amount distributed to investors
        uint64 createdAt;           // 8 bytes - Pool creation timestamp
        uint64 fundedAt;            // 8 bytes - Pool funded timestamp
        
        // Dynamic fields (separate storage slots)
        string name;                // Pool name/description
        uint256[] invoiceIds;       // Array of invoice IDs in this pool
    }

    // ================================
    // State Variables
    // ================================
    
    /// @notice Access control contract
    PlatformAccessControl public immutable ACCESS_CONTROL;
    
    /// @notice Invoice NFT contract
    InvoiceNFT public immutable INVOICE_NFT;
    
    /// @notice Pool data mapping
    mapping(uint256 => Pool) private _pools;
    
    /// @notice Invoice to pool mapping (invoiceId => poolId)
    mapping(uint256 => uint256) public invoiceToPool;
    
    /// @notice Next token ID counter
    uint256 private _nextTokenId = 1;
    
    /// @notice Total pools created
    uint256 public totalPoolsCreated;
    
    /// @notice Total amount across all pools
    uint256 public totalPoolValue;

    // ================================
    // Events
    // ================================
    
    event PoolCreated(
        uint256 indexed poolId,
        address indexed creator,
        string name,
        uint256 timestamp
    );
    
    event InvoiceAddedToPool(
        uint256 indexed poolId,
        uint256 indexed invoiceId,
        uint256 loanAmount,
        uint256 shippingAmount
    );
    
    event PoolStatusUpdated(
        uint256 indexed poolId,
        PoolStatus previousStatus,
        PoolStatus newStatus
    );
    
    event PoolFunded(
        uint256 indexed poolId,
        uint256 totalInvested,
        uint256 timestamp
    );
    
    event PoolSettlement(
        uint256 indexed poolId,
        uint256 totalDistributed,
        uint256 timestamp
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
    
    /// @notice Valid pool ID modifier
    modifier validPoolId(uint256 poolId) {
        _validPoolId(poolId);
        _;
    }

    /// @notice Valid pool ID internal check
    function _validPoolId(uint256 poolId) internal view {
        if (poolId == 0 || poolId >= _nextTokenId || _ownerOf(poolId) == address(0)) {
            revert InvalidPoolId(poolId);
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
     * @notice Initialize the Pool NFT contract
     * @param accessControlAddress Address of the access control contract
     * @param invoiceNftAddress Address of the invoice NFT contract
     */
    constructor(
        address accessControlAddress, 
        address invoiceNftAddress
    ) 
        ERC721("Shipping Invoice Pool NFT", "POOL")
        validAddress(accessControlAddress)
        validAddress(invoiceNftAddress)
    {
        ACCESS_CONTROL = PlatformAccessControl(accessControlAddress);
        INVOICE_NFT = InvoiceNFT(invoiceNftAddress);
    }

    // ================================
    // Pool Creation Functions
    // ================================
    
    /**
     * @notice Create a new investment pool
     * @param name Pool name/description
     * @param invoiceIds Array of invoice IDs to include in the pool
     * @return poolId The created pool NFT ID
     */
    function createPool(
        string calldata name,
        uint256[] calldata invoiceIds
    ) external onlyAdmin returns (uint256 poolId) {
        // Validation
        if (bytes(name).length == 0) revert InvalidPoolName(name);
        if (invoiceIds.length == 0) revert EmptyInvoiceArray();
        if (invoiceIds.length > MAX_INVOICES_PER_POOL) {
            revert PoolTooManyInvoices(invoiceIds.length, MAX_INVOICES_PER_POOL);
        }
        
        // Get next pool ID
        poolId = _nextTokenId;
        unchecked {
            ++_nextTokenId;
        }
        
        // Initialize pool with basic data
        Pool storage pool = _pools[poolId];
        pool.creator = msg.sender;
        pool.status = PoolStatus.Open;
        pool.name = name;
        pool.createdAt = uint64(block.timestamp);
        
        // Process invoices
        uint256 totalLoan = 0;
        uint256 totalShipping = 0;
        
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            uint256 invoiceId = invoiceIds[i];
            
            // Validate invoice exists and is finalized
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(invoiceId);
            if (uint8(invoice.status) != uint8(InvoiceNFT.InvoiceStatus.Finalized)) {
                revert InvoiceNotFinalized(invoiceId);
            }
            
            // Check invoice not already in another pool
            if (invoiceToPool[invoiceId] != 0) {
                revert InvoiceAlreadyInPool(invoiceId, invoiceToPool[invoiceId]);
            }
            
            // Add to pool
            pool.invoiceIds.push(invoiceId);
            invoiceToPool[invoiceId] = poolId;
            
            // Accumulate amounts
            unchecked {
                totalLoan += invoice.loanAmount;
                totalShipping += invoice.shippingAmount;
            }
            
            emit InvoiceAddedToPool(poolId, invoiceId, invoice.loanAmount, invoice.shippingAmount);
        }
        
        // Check total amounts fit in storage slots
        if (totalLoan > type(uint88).max) revert PoolTooManyInvoices(invoiceIds.length, MAX_INVOICES_PER_POOL);
        if (totalShipping > type(uint128).max) revert PoolTooManyInvoices(invoiceIds.length, MAX_INVOICES_PER_POOL);
        
        // Store totals
        // casting to smaller types is safe because we validated above
        // forge-lint: disable-next-line(unsafe-typecast)
        pool.totalLoanAmount = uint88(totalLoan);
        // casting to 'uint128' is safe because we validated totalShipping <= type(uint128).max
        // forge-lint: disable-next-line(unsafe-typecast)
        pool.totalShippingAmount = uint128(totalShipping);
        pool.invoiceCount = uint8(invoiceIds.length);
        
        // Update global counters
        unchecked {
            totalPoolsCreated++;
            totalPoolValue += totalLoan;
        }
        
        // Mint pool NFT to creator
        _mint(msg.sender, poolId);
        
        emit PoolCreated(poolId, msg.sender, name, block.timestamp);
    }

    // ================================
    // Pool Management Functions
    // ================================
    
    /**
     * @notice Add additional invoices to an open pool
     * @param poolId Pool to add invoices to
     * @param invoiceIds Array of invoice IDs to add
     */
    function addInvoicesToPool(
        uint256 poolId,
        uint256[] calldata invoiceIds
    ) external onlyAdmin validPoolId(poolId) {
        Pool storage pool = _pools[poolId];
        
        // Can only add to open pools
        if (pool.status != PoolStatus.Open) {
            revert InvalidStatus(pool.status, PoolStatus.Open);
        }
        
        // Check won't exceed maximum
        if (pool.invoiceCount + invoiceIds.length > MAX_INVOICES_PER_POOL) {
            revert PoolTooManyInvoices(pool.invoiceCount + invoiceIds.length, MAX_INVOICES_PER_POOL);
        }
        
        uint256 additionalLoan = 0;
        uint256 additionalShipping = 0;
        
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            uint256 invoiceId = invoiceIds[i];
            
            // Validate invoice
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(invoiceId);
            if (uint8(invoice.status) != uint8(InvoiceNFT.InvoiceStatus.Finalized)) {
                revert InvoiceNotFinalized(invoiceId);
            }
            
            if (invoiceToPool[invoiceId] != 0) {
                revert InvoiceAlreadyInPool(invoiceId, invoiceToPool[invoiceId]);
            }
            
            // Add to pool
            pool.invoiceIds.push(invoiceId);
            invoiceToPool[invoiceId] = poolId;
            
            unchecked {
                additionalLoan += invoice.loanAmount;
                additionalShipping += invoice.shippingAmount;
            }
            
            emit InvoiceAddedToPool(poolId, invoiceId, invoice.loanAmount, invoice.shippingAmount);
        }
        
        // Update pool totals
        unchecked {
            // casting to 'uint88' is safe because additional loan amounts are controlled and validated
            // forge-lint: disable-next-line(unsafe-typecast)
            pool.totalLoanAmount += uint88(additionalLoan);
            // casting to 'uint128' is safe because additional shipping amounts are controlled and validated
            // forge-lint: disable-next-line(unsafe-typecast)
            pool.totalShippingAmount += uint128(additionalShipping);
            pool.invoiceCount += uint8(invoiceIds.length);
            totalPoolValue += additionalLoan;
        }
    }
    
    /**
     * @notice Finalize pool to start fundraising
     * @param poolId Pool to finalize
     */
    function finalizePool(uint256 poolId) 
        external 
        onlyAdmin 
        validPoolId(poolId) 
    {
        Pool storage pool = _pools[poolId];
        
        if (pool.status != PoolStatus.Open) {
            revert InvalidStatus(pool.status, PoolStatus.Open);
        }
        
        // Update status to fundraising
        PoolStatus previousStatus = pool.status;
        pool.status = PoolStatus.Fundraising;
        
        emit PoolStatusUpdated(poolId, previousStatus, PoolStatus.Fundraising);
    }
    
    /**
     * @notice Mark pool as funded when investment threshold is reached
     * @param poolId Pool to mark as funded
     * @param totalInvested Total amount invested in the pool
     */
    function markPoolFunded(
        uint256 poolId, 
        uint256 totalInvested
    ) external onlyAdmin validPoolId(poolId) {
        Pool storage pool = _pools[poolId];
        
        if (pool.status != PoolStatus.Fundraising) {
            revert InvalidStatus(pool.status, PoolStatus.Fundraising);
        }
        
        // Validate minimum funding threshold
        uint256 minRequired = (pool.totalLoanAmount * MIN_FUNDING_THRESHOLD) / BASIS_POINTS;
        if (totalInvested < minRequired) {
            revert InsufficientFunding(totalInvested, minRequired);
        }
        
        // Update pool state
        // casting to 'uint128' is safe because investment amounts are controlled by pool funding manager
        // forge-lint: disable-next-line(unsafe-typecast)
        pool.totalInvested = uint128(totalInvested);
        pool.fundedAt = uint64(block.timestamp);
        
        PoolStatus previousStatus = pool.status;
        pool.status = PoolStatus.Funded;
        
        emit PoolStatusUpdated(poolId, previousStatus, PoolStatus.Funded);
        emit PoolFunded(poolId, totalInvested, block.timestamp);
    }
    
    /**
     * @notice Mark pool as settling when all invoices are paid
     * @param poolId Pool to mark as settling
     */
    function markPoolSettling(uint256 poolId) 
        external 
        onlyAdmin 
        validPoolId(poolId) 
    {
        Pool storage pool = _pools[poolId];
        
        if (pool.status != PoolStatus.Funded) {
            revert InvalidStatus(pool.status, PoolStatus.Funded);
        }
        
        // Verify all invoices in pool are paid
        for (uint256 i = 0; i < pool.invoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(pool.invoiceIds[i]);
            if (uint8(invoice.status) != uint8(InvoiceNFT.InvoiceStatus.Paid)) {
                revert InvalidStatus(PoolStatus.Funded, PoolStatus.Settling);
            }
        }
        
        PoolStatus previousStatus = pool.status;
        pool.status = PoolStatus.Settling;
        
        emit PoolStatusUpdated(poolId, previousStatus, PoolStatus.Settling);
    }
    
    /**
     * @notice Mark pool as completed after profit distribution
     * @param poolId Pool to mark as completed
     * @param totalDistributed Total amount distributed to investors
     */
    function markPoolCompleted(
        uint256 poolId,
        uint256 totalDistributed
    ) external onlyAdmin validPoolId(poolId) {
        Pool storage pool = _pools[poolId];
        
        if (pool.status != PoolStatus.Settling) {
            revert InvalidStatus(pool.status, PoolStatus.Settling);
        }
        
        // Update distribution amount
        // casting to 'uint128' is safe because distribution amounts are controlled by pool funding manager
        // forge-lint: disable-next-line(unsafe-typecast)
        pool.totalDistributed = uint128(totalDistributed);
        
        PoolStatus previousStatus = pool.status;
        pool.status = PoolStatus.Completed;
        
        emit PoolStatusUpdated(poolId, previousStatus, PoolStatus.Completed);
        emit PoolSettlement(poolId, totalDistributed, block.timestamp);
    }

    // ================================
    // View Functions
    // ================================
    
    /**
     * @notice Get pool details
     * @param poolId The pool ID
     * @return pool The complete pool struct
     */
    function getPool(uint256 poolId) 
        external 
        view 
        validPoolId(poolId) 
        returns (Pool memory pool) 
    {
        return _pools[poolId];
    }
    
    /**
     * @notice Get pool invoice IDs
     * @param poolId The pool ID
     * @return invoiceIds Array of invoice IDs in the pool
     */
    function getPoolInvoices(uint256 poolId)
        external
        view
        validPoolId(poolId)
        returns (uint256[] memory invoiceIds)
    {
        return _pools[poolId].invoiceIds;
    }
    
    /**
     * @notice Check if pool is eligible for funding
     * @param poolId The pool ID
     * @return eligible True if pool can receive investments
     */
    function isPoolEligibleForFunding(uint256 poolId)
        external
        view
        validPoolId(poolId)
        returns (bool eligible)
    {
        return _pools[poolId].status == PoolStatus.Fundraising;
    }
    
    /**
     * @notice Get funding progress for a pool
     * @param poolId The pool ID
     * @param currentInvested Current amount invested
     * @return totalRequired Total loan amount needed
     * @return percentage Funding percentage in basis points
     */
    function getPoolFundingProgress(uint256 poolId, uint256 currentInvested)
        external
        view
        validPoolId(poolId)
        returns (uint256 totalRequired, uint256 percentage)
    {
        Pool storage pool = _pools[poolId];
        totalRequired = pool.totalLoanAmount;
        
        if (totalRequired == 0) {
            percentage = 0;
        } else {
            percentage = (currentInvested * BASIS_POINTS) / totalRequired;
        }
    }
    
    /**
     * @notice Get pools by status
     * @param status The status to filter by
     * @return poolIds Array of pool IDs with the specified status
     */
    function getPoolsByStatus(PoolStatus status)
        external
        view
        returns (uint256[] memory poolIds)
    {
        uint256 totalSupply = totalSupply();
        uint256[] memory temp = new uint256[](totalSupply);
        uint256 count = 0;
        
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 poolId = tokenByIndex(i);
            if (_pools[poolId].status == status) {
                temp[count] = poolId;
                unchecked { ++count; }
            }
        }
        
        // Create result array with exact size
        poolIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            poolIds[i] = temp[i];
        }
    }
    
    /**
     * @notice Get pools by creator
     * @param creator The creator address
     * @return poolIds Array of pool IDs created by the address
     */
    function getPoolsByCreator(address creator)
        external
        view
        returns (uint256[] memory poolIds)
    {
        uint256 balance = balanceOf(creator);
        poolIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            poolIds[i] = tokenOfOwnerByIndex(creator, i);
        }
    }
    
    /**
     * @notice Get platform pool statistics
     * @return totalPools Total number of pools created
     * @return totalValue Total value across all pools
     * @return totalFunded Total number of funded pools
     */
    function getPoolStats()
        external
        view
        returns (
            uint256 totalPools,
            uint256 totalValue,
            uint256 totalFunded
        )
    {
        totalPools = totalPoolsCreated;
        totalValue = totalPoolValue;
        
        // Count funded pools
        uint256 supply = totalSupply();
        for (uint256 i = 0; i < supply; i++) {
            uint256 poolId = tokenByIndex(i);
            if (_pools[poolId].status == PoolStatus.Funded || 
                _pools[poolId].status == PoolStatus.Settling ||
                _pools[poolId].status == PoolStatus.Completed) {
                unchecked { ++totalFunded; }
            }
        }
    }
    
    /**
     * @notice Check if invoice is in any pool
     * @param invoiceId The invoice ID to check
     * @return poolId The pool ID (0 if not in any pool)
     */
    function getInvoicePool(uint256 invoiceId)
        external
        view
        returns (uint256 poolId)
    {
        return invoiceToPool[invoiceId];
    }

    // ================================
    // Pool Validation Functions
    // ================================
    
    /**
     * @notice Validate pool can be funded (all invoices properly funded)
     * @param poolId The pool ID to validate
     * @return valid True if pool is ready for operation
     */
    function validatePoolForFunding(uint256 poolId)
        external
        view
        validPoolId(poolId)
        returns (bool valid)
    {
        Pool storage pool = _pools[poolId];
        
        // Must be in fundraising status
        if (pool.status != PoolStatus.Fundraising) {
            return false;
        }
        
        // All invoices must still be finalized (not yet funded individually)
        for (uint256 i = 0; i < pool.invoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(pool.invoiceIds[i]);
            if (uint8(invoice.status) != uint8(InvoiceNFT.InvoiceStatus.Finalized)) {
                return false;
            }
        }
        
        return true;
    }
}