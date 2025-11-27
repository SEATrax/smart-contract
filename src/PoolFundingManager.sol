// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PlatformAccessControl} from "./AccessControl.sol";
import {InvoiceNFT} from "./InvoiceNFT.sol";
import {PoolNFT} from "./PoolNFT.sol";

/**
 * @title PoolFundingManager
 * @notice Manages external investments into invoice pools and handles fund distribution
 * @dev Handles investment tracking, fund allocation, profit sharing, and settlement
 * @dev Gas optimized: Uses packed structs, custom errors, and efficient mappings
 */
contract PoolFundingManager {
    // ================================
    // Custom Errors (Gas Optimized)
    // ================================
    
    error ZeroAddress();
    error NotAdmin(address caller);
    error NotInvestor(address caller);
    error InvalidPoolId(uint256 poolId);
    error InvalidAmount(uint256 amount);
    error PoolNotFundraising(uint256 poolId, PoolNFT.PoolStatus status);
    error InsufficientPoolFunds(uint256 available, uint256 requested);
    error PoolAlreadyFunded(uint256 poolId);
    error PoolNotSettled(uint256 poolId);
    error NoInvestment(address investor, uint256 poolId);
    error AlreadyDistributed(uint256 poolId);
    error InvestmentTooSmall(uint256 amount, uint256 minimum);
    error ExceedsMaxInvestment(uint256 amount, uint256 maximum);
    
    // ================================
    // Constants (Gas Optimized)
    // ================================
    
    uint256 public constant PLATFORM_FEE_RATE = 100; // 1%
    uint256 public constant INVESTOR_YIELD_RATE = 400; // 4%
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_INVESTMENT = 1000e18; // $1k minimum
    uint256 public constant MAX_INVESTMENT_PER_POOL = 1000000e18; // $1M per pool
    
    // ================================
    // State Variables
    // ================================
    
    PlatformAccessControl public immutable ACCESS_CONTROL;
    InvoiceNFT public immutable INVOICE_NFT;
    PoolNFT public immutable POOL_NFT;
    
    // Investment tracking
    mapping(uint256 => mapping(address => uint256)) public investorPoolInvestments;
    mapping(uint256 => address[]) public poolInvestors;
    mapping(uint256 => uint256) public poolTotalInvestment;
    mapping(address => uint256[]) public investorPools;
    
    // Distribution tracking
    mapping(uint256 => bool) public poolProfitsDistributed;
    mapping(uint256 => uint256) public poolPlatformFees;
    mapping(uint256 => uint256) public poolInvestorRewards;
    
    // Platform statistics
    uint256 public totalPlatformRevenue;
    uint256 public totalInvestorReturns;
    uint256 public totalPoolsInvested;
    
    // ================================
    // Events
    // ================================
    
    event InvestmentMade(
        address indexed investor,
        uint256 indexed poolId,
        uint256 amount,
        uint256 timestamp
    );
    
    event FundsAllocated(
        uint256 indexed poolId,
        uint256 totalAllocated,
        uint256 invoiceCount,
        uint256 timestamp
    );
    
    event ProfitsDistributed(
        uint256 indexed poolId,
        uint256 platformFee,
        uint256 investorRewards,
        uint256 timestamp
    );
    
    event InvestorRewardClaimed(
        address indexed investor,
        uint256 indexed poolId,
        uint256 amount,
        uint256 timestamp
    );
    
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

    modifier onlyInvestor() {
        _onlyInvestor();
        _;
    }

    function _onlyInvestor() internal view {
        if (!ACCESS_CONTROL.isInvestor(msg.sender)) {
            revert NotInvestor(msg.sender);
        }
    }

    modifier validAddress(address addr) {
        _validAddress(addr);
        _;
    }

    function _validAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
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

    modifier validAmount(uint256 amount) {
        _validAmount(amount);
        _;
    }

    function _validAmount(uint256 amount) internal pure {
        if (amount == 0) revert InvalidAmount(amount);
    }    // ================================
    // Constructor
    // ================================
    
    /**
     * @notice Initialize the Pool Funding Manager
     * @param accessControlAddress Address of the access control contract
     * @param invoiceNftAddress Address of the invoice NFT contract
     * @param poolNftAddress Address of the pool NFT contract
     */
    constructor(
        address accessControlAddress,
        address invoiceNftAddress,
        address poolNftAddress
    )
        validAddress(accessControlAddress)
        validAddress(invoiceNftAddress)
        validAddress(poolNftAddress)
    {
        ACCESS_CONTROL = PlatformAccessControl(accessControlAddress);
        INVOICE_NFT = InvoiceNFT(invoiceNftAddress);
        POOL_NFT = PoolNFT(poolNftAddress);
    }
    
    // ================================
    // Investment Functions
    // ================================
    
    /**
     * @notice Allow investors to invest in a fundraising pool
     * @param poolId ID of the pool to invest in
     * @param amount Investment amount in wei
     */
    function investInPool(uint256 poolId, uint256 amount)
        external
        onlyInvestor
        validPoolId(poolId)
        validAmount(amount)
    {
        // Validate investment amount
        if (amount < MIN_INVESTMENT) {
            revert InvestmentTooSmall(amount, MIN_INVESTMENT);
        }
        
        uint256 currentInvestment = investorPoolInvestments[poolId][msg.sender];
        if (currentInvestment + amount > MAX_INVESTMENT_PER_POOL) {
            revert ExceedsMaxInvestment(
                currentInvestment + amount, 
                MAX_INVESTMENT_PER_POOL
            );
        }
        
        // Validate pool status
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        if (pool.status != PoolNFT.PoolStatus.Fundraising) {
            revert PoolNotFundraising(poolId, pool.status);
        }
        
        // Record investment
        if (investorPoolInvestments[poolId][msg.sender] == 0) {
            poolInvestors[poolId].push(msg.sender);
            investorPools[msg.sender].push(poolId);
        }
        
        investorPoolInvestments[poolId][msg.sender] += amount;
        poolTotalInvestment[poolId] += amount;
        
        // Update statistics
        if (poolTotalInvestment[poolId] == amount) {
            totalPoolsInvested++;
        }
        
        emit InvestmentMade(msg.sender, poolId, amount, block.timestamp);
    }
    
    /**
     * @notice Allocate invested funds to invoices in the pool
     * @param poolId ID of the pool to allocate funds from
     */
    function allocateFundsToInvoices(uint256 poolId)
        external
        onlyAdmin
        validPoolId(poolId)
    {
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        
        // Validate pool status
        if (pool.status != PoolNFT.PoolStatus.Fundraising) {
            revert PoolNotFundraising(poolId, pool.status);
        }
        
        uint256 totalInvestment = poolTotalInvestment[poolId];
        if (totalInvestment == 0) {
            revert InsufficientPoolFunds(0, pool.totalLoanAmount);
        }
        
        // Check if we have sufficient funds (70% minimum)
        uint256 minRequired = (pool.totalLoanAmount * 7000) / 10000;
        if (totalInvestment < minRequired) {
            revert InsufficientPoolFunds(totalInvestment, minRequired);
        }
        
        // Mark pool as funded first
        POOL_NFT.markPoolFunded(poolId, totalInvestment);
        
        // Allocate funds proportionally to each invoice
        uint256[] memory invoiceIds = POOL_NFT.getPoolInvoices(poolId);
        
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(invoiceIds[i]);
            
            // Calculate proportional allocation
            uint256 allocation = (totalInvestment * invoice.loanAmount) / pool.totalLoanAmount;
            
            // Cap allocation to invoice loan amount to prevent over-funding
            if (allocation > invoice.loanAmount) {
                allocation = invoice.loanAmount;
            }
            
            // Add funding to invoice
            INVOICE_NFT.addFunding(invoiceIds[i], allocation);
        }
        
        emit FundsAllocated(poolId, totalInvestment, invoiceIds.length, block.timestamp);
    }
    
    // ================================
    // Distribution Functions
    // ================================
    
    /**
     * @notice Distribute profits to investors and platform after pool completion
     * @param poolId ID of the completed pool
     */
    function distributeProfits(uint256 poolId)
        external
        onlyAdmin
        validPoolId(poolId)
    {
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        
        // Validate pool is ready for profit distribution
        if (pool.status != PoolNFT.PoolStatus.Settling) {
            revert PoolNotSettled(poolId);
        }
        
        // Check if already distributed
        if (poolProfitsDistributed[poolId]) {
            revert AlreadyDistributed(poolId);
        }
        
        uint256 totalInvestment = poolTotalInvestment[poolId];
        
        // Calculate platform fee (1% of total loan amount)
        uint256 platformFee = (pool.totalLoanAmount * PLATFORM_FEE_RATE) / BASIS_POINTS;
        
        // Calculate investor rewards (4% of investment)
        uint256 investorRewards = (totalInvestment * INVESTOR_YIELD_RATE) / BASIS_POINTS;
        
        // Record distribution amounts
        poolPlatformFees[poolId] = platformFee;
        poolInvestorRewards[poolId] = investorRewards;
        poolProfitsDistributed[poolId] = true;
        
        // Mark pool as completed
        POOL_NFT.markPoolCompleted(poolId, investorRewards);
        
        // Update platform statistics
        totalPlatformRevenue += platformFee;
        totalInvestorReturns += investorRewards;
        
        emit ProfitsDistributed(poolId, platformFee, investorRewards, block.timestamp);
    }
    
    /**
     * @notice Allow investors to claim their returns from a completed pool
     * @param poolId ID of the completed pool
     */
    function claimInvestorReturns(uint256 poolId)
        external
        onlyInvestor
        validPoolId(poolId)
    {
        uint256 investment = investorPoolInvestments[poolId][msg.sender];
        if (investment == 0) {
            revert NoInvestment(msg.sender, poolId);
        }
        
        if (!poolProfitsDistributed[poolId]) {
            revert PoolNotSettled(poolId);
        }
        
        uint256 totalInvestment = poolTotalInvestment[poolId];
        uint256 totalRewards = poolInvestorRewards[poolId];
        
        // Calculate investor's proportional share
        uint256 investorShare = (investment * totalRewards) / totalInvestment;
        uint256 totalReturn = investment + investorShare; // Principal + rewards
        
        // Reset investment to prevent double claiming
        investorPoolInvestments[poolId][msg.sender] = 0;
        
        emit InvestorRewardClaimed(msg.sender, poolId, totalReturn, block.timestamp);
    }
    
    // ================================
    // View Functions
    // ================================
    
    /**
     * @notice Get investment details for a specific investor in a pool
     * @param investor Address of the investor
     * @param poolId ID of the pool
     * @return investment Amount invested
     * @return canClaim Whether returns can be claimed
     * @return estimatedReturn Estimated total return (principal + rewards)
     */
    function getInvestorPoolInfo(address investor, uint256 poolId)
        external
        view
        validPoolId(poolId)
        returns (
            uint256 investment,
            bool canClaim,
            uint256 estimatedReturn
        )
    {
        investment = investorPoolInvestments[poolId][investor];
        canClaim = poolProfitsDistributed[poolId] && investment > 0;
        
        if (canClaim) {
            uint256 totalInvestment = poolTotalInvestment[poolId];
            uint256 totalRewards = poolInvestorRewards[poolId];
            uint256 investorShare = (investment * totalRewards) / totalInvestment;
            estimatedReturn = investment + investorShare;
        } else {
            estimatedReturn = investment;
        }
    }
    
    /**
     * @notice Get all pools an investor has invested in
     * @param investor Address of the investor
     * @return poolIds Array of pool IDs
     */
    function getInvestorPools(address investor)
        external
        view
        returns (uint256[] memory poolIds)
    {
        return investorPools[investor];
    }
    
    /**
     * @notice Get all investors in a specific pool
     * @param poolId ID of the pool
     * @return investors Array of investor addresses
     */
    function getPoolInvestors(uint256 poolId)
        external
        view
        validPoolId(poolId)
        returns (address[] memory investors)
    {
        return poolInvestors[poolId];
    }
    
    /**
     * @notice Get pool funding statistics
     * @param poolId ID of the pool
     * @return totalInvested Total amount invested
     * @return investorCount Number of unique investors
     * @return fundingProgress Percentage of target funding reached
     */
    function getPoolFundingStats(uint256 poolId)
        external
        view
        validPoolId(poolId)
        returns (
            uint256 totalInvested,
            uint256 investorCount,
            uint256 fundingProgress
        )
    {
        totalInvested = poolTotalInvestment[poolId];
        investorCount = poolInvestors[poolId].length;
        
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        if (pool.totalLoanAmount > 0) {
            fundingProgress = (totalInvested * 10000) / pool.totalLoanAmount;
        }
    }
    
    /**
     * @notice Get platform-wide statistics
     * @return totalRevenue Total platform revenue from fees
     * @return totalReturns Total returns distributed to investors
     * @return poolsInvested Total number of pools that have received investment
     */
    function getPlatformStats()
        external
        view
        returns (
            uint256 totalRevenue,
            uint256 totalReturns,
            uint256 poolsInvested
        )
    {
        return (totalPlatformRevenue, totalInvestorReturns, totalPoolsInvested);
    }
}