// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PlatformAccessControl} from "./AccessControl.sol";
import {InvoiceNFT} from "./InvoiceNFT.sol";
import {PoolNFT} from "./PoolNFT.sol";
import {PoolFundingManager} from "./PoolFundingManager.sol";
import {PaymentOracle} from "./PaymentOracle.sol";

/**
 * @title PlatformAnalytics
 * @notice Comprehensive analytics and reporting system for the shipping invoice funding platform
 * @dev Provides portfolio tracking, performance metrics, and reporting dashboard functionality
 * 
 * Key Features:
 * - Real-time portfolio tracking for investors and platform
 * - Performance metrics and ROI calculations
 * - Historical data tracking and trend analysis
 * - Risk assessment and pool performance metrics
 * - Comprehensive reporting for all stakeholders
 * 
 * @author SEATrax Team
 */
contract PlatformAnalytics {
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
    
    /// @notice Reference to the payment oracle contract
    PaymentOracle public immutable PAYMENT_ORACLE;

    // ================================
    // Analytics Data Structures
    // ================================

    /// @notice Global platform statistics
    struct PlatformMetrics {
        uint256 totalInvoicesCreated;        // Total invoices minted
        uint256 totalPoolsCreated;           // Total pools created
        uint256 totalValueLocked;            // Total funds locked in platform
        uint256 totalValueProcessed;         // Total value of completed invoices
        uint256 totalPlatformFees;           // Total fees collected by platform
        uint256 totalInvestorReturns;        // Total returns paid to investors
        uint256 activeInvoices;              // Currently active invoices
        uint256 activePools;                 // Currently active pools
        uint256 uniqueInvestors;             // Number of unique investors
        uint256 uniqueExporters;             // Number of unique exporters
    }

    /// @notice Individual investor portfolio metrics
    struct InvestorPortfolio {
        uint256 totalInvested;              // Total amount invested across all pools
        uint256 totalReturns;               // Total returns received
        uint256 activeInvestments;          // Current active investments
        uint256 completedInvestments;       // Number of completed investments
        uint256 averageRoi;                 // Average return on investment (basis points)
        uint256 totalPoolsInvested;         // Number of pools invested in
        uint256 lastInvestmentTimestamp;    // Timestamp of last investment
        uint256 riskScore;                  // Risk assessment score (0-10000)
    }

    /// @notice Pool performance metrics
    struct PoolPerformance {
        uint256 poolId;                     // Pool identifier
        uint256 totalFunded;                // Total amount funded
        uint256 totalReturned;              // Total amount returned to investors
        uint256 completionRate;             // Percentage of invoices completed (basis points)
        uint256 averageTimeToCompletion;    // Average time from funding to completion
        uint256 investorCount;              // Number of investors in pool
        uint256 riskRating;                 // Risk assessment (0-10000)
        uint256 actualRoi;                  // Actual ROI achieved (basis points)
        bool isCompleted;                   // Whether pool is fully completed
        uint256 completedTimestamp;         // When pool was completed
    }

    /// @notice Exporter performance tracking
    struct ExporterMetrics {
        uint256 totalInvoicesCreated;       // Total invoices created by exporter
        uint256 totalValueShipped;          // Total shipping value
        uint256 averageInvoiceValue;        // Average invoice value
        uint256 completionRate;             // Invoice completion rate (basis points)
        uint256 averagePaymentTime;         // Average time to receive payment
        uint256 defaultRate;                // Rate of invoice defaults (basis points)
        uint256 totalPoolsParticipated;     // Number of pools participated in
        uint256 lastActivityTimestamp;      // Last invoice activity
        uint256 reliabilityScore;           // Exporter reliability score (0-10000)
    }

    /// @notice Time-based analytics for trend analysis
    struct TimeSeriesData {
        uint256 timestamp;                  // Data point timestamp
        uint256 totalVolume;                // Total transaction volume
        uint256 newInvestments;             // New investments in period
        uint256 completedInvoices;          // Invoices completed in period
        uint256 averageRoi;                 // Average ROI in period
        uint256 platformUtilization;       // Platform utilization rate
    }

    // ================================
    // Storage Mappings
    // ================================

    /// @notice Investor portfolio data
    mapping(address => InvestorPortfolio) public investorPortfolios;
    
    /// @notice Pool performance data
    mapping(uint256 => PoolPerformance) public poolPerformance;
    
    /// @notice Exporter metrics data
    mapping(address => ExporterMetrics) public exporterMetrics;
    
    /// @notice Time series data for trend analysis (timestamp => data)
    mapping(uint256 => TimeSeriesData) public historicalData;
    
    /// @notice Platform-wide metrics
    PlatformMetrics public platformMetrics;
    
    /// @notice Last update timestamp for each metric
    mapping(bytes32 => uint256) public lastUpdateTimestamp;
    
    /// @notice ROI tracking for completed pools
    mapping(uint256 => uint256) public poolRoi;
    
    /// @notice Risk scores for pools (calculated metrics)
    mapping(uint256 => uint256) public poolRiskScores;

    // ================================
    // Constants
    // ================================

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_RISK_SCORE = 10000;
    uint256 public constant TIME_SERIES_INTERVAL = 1 days;
    uint256 public constant STALENESS_THRESHOLD = 1 hours;

    // ================================
    // Events
    // ================================

    event MetricsUpdated(
        bytes32 indexed metricType,
        address indexed entity,
        uint256 timestamp
    );
    
    event PortfolioUpdated(
        address indexed investor,
        uint256 totalInvested,
        uint256 totalReturns,
        uint256 timestamp
    );
    
    event PoolAnalysisCompleted(
        uint256 indexed poolId,
        uint256 actualRoi,
        uint256 riskRating,
        uint256 timestamp
    );
    
    event PlatformSnapshotCreated(
        uint256 timestamp,
        uint256 totalVolume,
        uint256 activeUsers
    );

    // ================================
    // Errors
    // ================================

    error ZeroAddress();
    error NotAdmin(address caller);
    error InvalidPoolId(uint256 poolId);
    error InvalidTimestamp(uint256 timestamp);
    error StaleData(uint256 lastUpdate, uint256 threshold);
    error CalculationError(string reason);

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
        address invoiceNft_,
        address poolNft_,
        address poolFundingManager,
        address paymentOracle
    ) {
        if (accessControl == address(0)) revert ZeroAddress();
        if (invoiceNft_ == address(0)) revert ZeroAddress();
        if (poolNft_ == address(0)) revert ZeroAddress();
        if (poolFundingManager == address(0)) revert ZeroAddress();
        if (paymentOracle == address(0)) revert ZeroAddress();

        ACCESS_CONTROL = PlatformAccessControl(accessControl);
        INVOICE_NFT = InvoiceNFT(invoiceNft_);
        POOL_NFT = PoolNFT(poolNft_);
        POOL_FUNDING_MANAGER = PoolFundingManager(poolFundingManager);
        PAYMENT_ORACLE = PaymentOracle(paymentOracle);
    }

    // ================================
    // Analytics Update Functions
    // ================================

    /**
     * @notice Update platform-wide metrics
     */
    function updatePlatformMetrics() external onlyAdmin {
        PlatformMetrics storage metrics = platformMetrics;
        
        // Update basic counts
        metrics.totalInvoicesCreated = INVOICE_NFT.totalSupply();
        metrics.totalPoolsCreated = POOL_NFT.totalSupply();
        
        // Calculate platform statistics
        (
            metrics.totalValueLocked,
            metrics.totalValueProcessed,
            metrics.activeInvoices,
            metrics.activePools
        ) = _calculatePlatformVolumes();
        
        // Update user counts
        (
            metrics.uniqueInvestors,
            metrics.uniqueExporters
        ) = _calculateUserCounts();
        
        // Update financial metrics
        metrics.totalPlatformFees = _calculateTotalPlatformFees();
        metrics.totalInvestorReturns = _calculateTotalInvestorReturns();
        
        lastUpdateTimestamp["platform"] = block.timestamp;
        
        emit MetricsUpdated("platform", address(0), block.timestamp);
    }

    /**
     * @notice Update investor portfolio metrics
     * @param investor Address of the investor to update
     */
    function updateInvestorPortfolio(address investor) external {
        if (investor == address(0)) revert ZeroAddress();
        
        InvestorPortfolio storage portfolio = investorPortfolios[investor];
        
        // Calculate investment totals
        (
            portfolio.totalInvested,
            portfolio.totalReturns,
            portfolio.activeInvestments,
            portfolio.completedInvestments,
            portfolio.totalPoolsInvested
        ) = _calculateInvestorTotals(investor);
        
        // Calculate performance metrics
        portfolio.averageRoi = _calculateInvestorRoi(investor);
        portfolio.riskScore = _calculateInvestorRiskScore(investor);
        portfolio.lastInvestmentTimestamp = _getLastInvestmentTimestamp(investor);
        
        emit PortfolioUpdated(
            investor,
            portfolio.totalInvested,
            portfolio.totalReturns,
            block.timestamp
        );
    }

    /**
     * @notice Update pool performance metrics
     * @param poolId ID of the pool to analyze
     */
    function updatePoolPerformance(uint256 poolId) external validPoolId(poolId) {
        PoolPerformance storage performance = poolPerformance[poolId];
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        
        performance.poolId = poolId;
        performance.totalFunded = pool.totalInvested;
        performance.investorCount = _getPoolInvestorCount(poolId);
        
        // Calculate completion metrics
        (
            performance.completionRate,
            performance.averageTimeToCompletion,
            performance.isCompleted
        ) = _calculatePoolCompletion(poolId);
        
        // Calculate financial performance
        if (performance.isCompleted) {
            performance.totalReturned = _calculatePoolReturns(poolId);
            performance.actualRoi = _calculatePoolRoi(poolId);
            performance.completedTimestamp = block.timestamp;
            poolRoi[poolId] = performance.actualRoi;
        }
        
        // Calculate risk rating
        performance.riskRating = _calculatePoolRiskRating(poolId);
        poolRiskScores[poolId] = performance.riskRating;
        
        emit PoolAnalysisCompleted(
            poolId,
            performance.actualRoi,
            performance.riskRating,
            block.timestamp
        );
    }

    /**
     * @notice Update exporter performance metrics
     * @param exporter Address of the exporter to analyze
     */
    function updateExporterMetrics(address exporter) external {
        if (exporter == address(0)) revert ZeroAddress();
        
        ExporterMetrics storage metrics = exporterMetrics[exporter];
        
        // Calculate basic statistics
        (
            metrics.totalInvoicesCreated,
            metrics.totalValueShipped,
            metrics.averageInvoiceValue
        ) = _calculateExporterVolumes(exporter);
        
        // Calculate performance metrics
        (
            metrics.completionRate,
            metrics.averagePaymentTime,
            metrics.defaultRate
        ) = _calculateExporterPerformance(exporter);
        
        // Calculate reliability and participation
        metrics.totalPoolsParticipated = _getExporterPoolCount(exporter);
        metrics.reliabilityScore = _calculateExporterReliability(exporter);
        metrics.lastActivityTimestamp = _getExporterLastActivity(exporter);
        
        lastUpdateTimestamp[keccak256(abi.encode("exporter", exporter))] = block.timestamp;
        
        emit MetricsUpdated("exporter", exporter, block.timestamp);
    }

    /**
     * @notice Create historical data snapshot
     */
    function createHistoricalSnapshot() external onlyAdmin {
        uint256 currentDay = block.timestamp - (block.timestamp % TIME_SERIES_INTERVAL);
        
        TimeSeriesData storage data = historicalData[currentDay];
        data.timestamp = currentDay;
        
        // Calculate current metrics
        data.totalVolume = _calculateCurrentVolume();
        data.newInvestments = _calculateNewInvestments(currentDay);
        data.completedInvoices = _calculateCompletedInvoices(currentDay);
        data.averageRoi = _calculateCurrentAverageRoi();
        data.platformUtilization = _calculatePlatformUtilization();
        
        emit PlatformSnapshotCreated(
            currentDay,
            data.totalVolume,
            platformMetrics.uniqueInvestors
        );
    }

    // ================================
    // View Functions - Portfolio Analytics
    // ================================

    /**
     * @notice Get exporter performance metrics
     * @param exporter Address of the exporter
     * @return metrics Complete exporter metrics
     */
    function getExporterMetrics(address exporter) 
        external 
        view 
        returns (ExporterMetrics memory metrics) 
    {
        return exporterMetrics[exporter];
    }

    /**
     * @notice Get comprehensive investor portfolio analysis
     * @param investor Address of the investor
     * @return portfolio Complete portfolio metrics
     */
    function getInvestorPortfolio(address investor) 
        external 
        view 
        returns (InvestorPortfolio memory portfolio) 
    {
        return investorPortfolios[investor];
    }

    /**
     * @notice Get investor performance across all pools
     * @param investor Address of the investor
     * @return poolIds Array of pool IDs invested in
     * @return investments Array of investment amounts
     * @return investorReturns Array of returns received
     * @return rois Array of ROI for each pool
     */
    function getInvestorPoolBreakdown(address investor)
        external
        view
        returns (
            uint256[] memory poolIds,
            uint256[] memory investments,
            uint256[] memory investorReturns,
            uint256[] memory rois
        )
    {
        uint256 poolCount = POOL_NFT.totalSupply();
        uint256 investorPoolCount = 0;
        
        // Count investor's pools
        for (uint256 i = 1; i <= poolCount; i++) {
            if (POOL_FUNDING_MANAGER.investorPoolInvestments(i, investor) > 0) {
                investorPoolCount++;
            }
        }
        
        // Allocate arrays
        poolIds = new uint256[](investorPoolCount);
        investments = new uint256[](investorPoolCount);
        investorReturns = new uint256[](investorPoolCount);
        rois = new uint256[](investorPoolCount);
        
        // Populate data
        uint256 index = 0;
        for (uint256 i = 1; i <= poolCount; i++) {
            uint256 investment = POOL_FUNDING_MANAGER.investorPoolInvestments(i, investor);
            if (investment > 0) {
                poolIds[index] = i;
                investments[index] = investment;
                investorReturns[index] = _getInvestorPoolReturns(investor, i);
                rois[index] = _calculateInvestorPoolRoi(investor, i);
                index++;
            }
        }
    }

    /**
     * @notice Get top performing investors
     * @param limit Number of top investors to return
     * @return investors Array of investor addresses
     * @return totalReturns Array of total returns for each investor
     * @return rois Array of average ROI for each investor
     */
    function getTopInvestors(uint256 limit)
        external
        pure
        returns (
            address[] memory investors,
            uint256[] memory totalReturns,
            uint256[] memory rois
        )
    {
        // Note: This is a simplified implementation
        // In production, you'd want to maintain a sorted list or use off-chain indexing
        investors = new address[](limit);
        totalReturns = new uint256[](limit);
        rois = new uint256[](limit);
        
        // This would need to be implemented with proper indexing
        // For now, returning empty arrays as placeholder
        return (investors, totalReturns, rois);
    }

    // ================================
    // View Functions - Pool Analytics
    // ================================

    /**
     * @notice Get comprehensive pool performance analysis
     * @param poolId ID of the pool
     * @return performance Complete pool performance metrics
     */
    function getPoolPerformance(uint256 poolId) 
        external 
        view 
        validPoolId(poolId)
        returns (PoolPerformance memory performance) 
    {
        return poolPerformance[poolId];
    }

    /**
     * @notice Get pool risk assessment details
     * @param poolId ID of the pool
     * @return riskScore Overall risk score (0-10000)
     * @return riskFactors Array of individual risk factor scores
     * @return riskDescriptions Array of risk factor descriptions
     */
    function getPoolRiskAssessment(uint256 poolId)
        external
        view
        validPoolId(poolId)
        returns (
            uint256 riskScore,
            uint256[] memory riskFactors,
            string[] memory riskDescriptions
        )
    {
        riskScore = poolRiskScores[poolId];
        
        // Risk factors analysis
        riskFactors = new uint256[](5);
        riskDescriptions = new string[](5);
        
        // Diversification risk
        riskFactors[0] = _assessDiversificationRisk(poolId);
        riskDescriptions[0] = "Invoice Diversification Risk";
        
        // Concentration risk
        riskFactors[1] = _assessConcentrationRisk(poolId);
        riskDescriptions[1] = "Exporter Concentration Risk";
        
        // Liquidity risk
        riskFactors[2] = _assessLiquidityRisk(poolId);
        riskDescriptions[2] = "Pool Liquidity Risk";
        
        // Credit risk
        riskFactors[3] = _assessCreditRisk(poolId);
        riskDescriptions[3] = "Exporter Credit Risk";
        
        // Market risk
        riskFactors[4] = _assessMarketRisk(poolId);
        riskDescriptions[4] = "Market Condition Risk";
    }

    /**
     * @notice Get pools sorted by performance
     * @param sortBy 0=ROI, 1=Volume, 2=Risk, 3=Completion
     * @param limit Number of pools to return
     * @return poolIds Array of sorted pool IDs
     * @return metrics Array of corresponding metrics
     */
    function getPoolsRanked(
        uint256 sortBy,
        uint256 limit
    ) 
        external 
        view
        returns (
            uint256[] memory poolIds,
            uint256[] memory metrics
        )
    {
        uint256 totalPools = POOL_NFT.totalSupply();
        
        poolIds = new uint256[](limit > totalPools ? totalPools : limit);
        metrics = new uint256[](poolIds.length);
        
        // Simplified ranking implementation
        // In production, this would use more efficient sorting
        uint256 count = 0;
        for (uint256 i = 1; i <= totalPools && count < limit; i++) {
            poolIds[count] = i;
            
            if (sortBy == 0) {
                metrics[count] = poolRoi[i];
            } else if (sortBy == 1) {
                PoolNFT.Pool memory pool = POOL_NFT.getPool(i);
                metrics[count] = pool.totalInvested;
            } else if (sortBy == 2) {
                metrics[count] = poolRiskScores[i];
            } else {
                metrics[count] = poolPerformance[i].completionRate;
            }
            count++;
        }
        
        return (poolIds, metrics);
    }

    // ================================
    // Internal Calculation Functions
    // ================================

    function _calculatePlatformVolumes() 
        internal 
        view 
        returns (
            uint256 totalValueLocked,
            uint256 totalValueProcessed,
            uint256 activeInvoices,
            uint256 activePools
        ) 
    {
        uint256 invoiceCount = INVOICE_NFT.totalSupply();
        uint256 poolCount = POOL_NFT.totalSupply();
        
        for (uint256 i = 1; i <= invoiceCount; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(i);
            
            if (invoice.status == InvoiceNFT.InvoiceStatus.Funded ||
                invoice.status == InvoiceNFT.InvoiceStatus.Fundraising) {
                totalValueLocked += invoice.amountInvested;
                activeInvoices++;
            } else if (invoice.status == InvoiceNFT.InvoiceStatus.Paid) {
                totalValueProcessed += invoice.shippingAmount;
            }
        }
        
        for (uint256 i = 1; i <= poolCount; i++) {
            PoolNFT.Pool memory pool = POOL_NFT.getPool(i);
            
            if (pool.status == PoolNFT.PoolStatus.Fundraising ||
                pool.status == PoolNFT.PoolStatus.Funded ||
                pool.status == PoolNFT.PoolStatus.Settling) {
                activePools++;
            }
        }
    }

    function _calculateUserCounts() 
        internal 
        pure 
        returns (uint256 uniqueInvestors, uint256 uniqueExporters) 
    {
        // This would require maintaining user registries
        // Simplified implementation - actual count would need event indexing
        uniqueInvestors = 0; // Placeholder
        uniqueExporters = 0; // Placeholder
    }

    function _calculateTotalPlatformFees() internal pure returns (uint256) {
        // Calculate based on completed transactions
        // Would need to track fee collection events
        return 0; // Placeholder
    }

    function _calculateTotalInvestorReturns() internal pure returns (uint256) {
        // Sum all investor returns across all pools
        // Would need to track distribution events
        return 0; // Placeholder
    }

    function _calculateInvestorTotals(address investor)
        internal
        view
        returns (
            uint256 totalInvested,
            uint256 totalReturns,
            uint256 activeInvestments,
            uint256 completedInvestments,
            uint256 totalPoolsInvested
        )
    {
        uint256 poolCount = POOL_NFT.totalSupply();
        
        for (uint256 i = 1; i <= poolCount; i++) {
            uint256 investment = POOL_FUNDING_MANAGER.investorPoolInvestments(i, investor);
            if (investment > 0) {
                totalInvested += investment;
                totalPoolsInvested++;
                
                PoolNFT.Pool memory pool = POOL_NFT.getPool(i);
                if (pool.status == PoolNFT.PoolStatus.Completed) {
                    completedInvestments++;
                    totalReturns += _getInvestorPoolReturns(investor, i);
                } else {
                    activeInvestments += investment;
                }
            }
        }
    }

    function _calculateInvestorRoi(address investor) internal view returns (uint256) {
        uint256 totalInvested = investorPortfolios[investor].totalInvested;
        uint256 totalReturns = investorPortfolios[investor].totalReturns;
        
        if (totalInvested == 0) return 0;
        
        return (totalReturns * BASIS_POINTS) / totalInvested;
    }

    function _calculateInvestorRiskScore(address /* investor */) internal pure returns (uint256) {
        // Calculate based on portfolio diversification and risk factors
        // Placeholder implementation
        return 5000; // Medium risk
    }

    function _getLastInvestmentTimestamp(address /* investor */) internal pure returns (uint256) {
        // Would need to track investment events
        return 0; // Placeholder
    }

    function _calculatePoolCompletion(uint256 poolId)
        internal
        view
        returns (
            uint256 completionRate,
            uint256 averageTimeToCompletion,
            bool isCompleted
        )
    {
        uint256[] memory invoiceIds = POOL_NFT.getPoolInvoices(poolId);
        uint256 completedCount = 0;
        uint256 totalTime = 0;
        
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(invoiceIds[i]);
            
            if (invoice.status == InvoiceNFT.InvoiceStatus.Paid) {
                completedCount++;
                // Calculate time to completion (placeholder)
                totalTime += 30 days; // Simplified
            }
        }
        
        completionRate = (completedCount * BASIS_POINTS) / invoiceIds.length;
        isCompleted = completedCount == invoiceIds.length;
        averageTimeToCompletion = completedCount > 0 ? totalTime / completedCount : 0;
    }

    function _calculatePoolReturns(uint256 /* poolId */) internal pure returns (uint256) {
        // Calculate total returns for the pool
        // Would need to track distribution events
        return 0; // Placeholder
    }

    function _calculatePoolRoi(uint256 poolId) internal view returns (uint256) {
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        uint256 totalReturns = _calculatePoolReturns(poolId);
        
        if (pool.totalInvested == 0) return 0;
        
        return (totalReturns * BASIS_POINTS) / pool.totalInvested;
    }

    function _calculatePoolRiskRating(uint256 poolId) internal view returns (uint256) {
        // Comprehensive risk assessment
        uint256 diversificationRisk = _assessDiversificationRisk(poolId);
        uint256 concentrationRisk = _assessConcentrationRisk(poolId);
        uint256 liquidityRisk = _assessLiquidityRisk(poolId);
        uint256 creditRisk = _assessCreditRisk(poolId);
        uint256 marketRisk = _assessMarketRisk(poolId);
        
        // Weighted average of risk factors
        return (diversificationRisk * 20 + concentrationRisk * 25 + liquidityRisk * 15 + 
                creditRisk * 30 + marketRisk * 10) / 100;
    }

    // Risk assessment helper functions
    function _assessDiversificationRisk(uint256 poolId) internal view returns (uint256) {
        uint256[] memory invoiceIds = POOL_NFT.getPoolInvoices(poolId);
        // More invoices = lower risk
        if (invoiceIds.length >= 10) return 1000; // Low risk
        if (invoiceIds.length >= 5) return 5000;  // Medium risk
        return 9000; // High risk
    }

    function _assessConcentrationRisk(uint256 /* poolId */) internal pure returns (uint256) {
        // Check exporter concentration
        return 5000; // Placeholder - medium risk
    }

    function _assessLiquidityRisk(uint256 poolId) internal view returns (uint256) {
        PoolNFT.Pool memory pool = POOL_NFT.getPool(poolId);
        // Larger pools typically have better liquidity
        if (pool.totalInvested >= 1000000e18) return 2000; // Low risk
        if (pool.totalInvested >= 100000e18) return 5000;  // Medium risk
        return 8000; // High risk
    }

    function _assessCreditRisk(uint256 /* poolId */) internal pure returns (uint256) {
        // Assess based on exporter history and reliability
        return 4000; // Placeholder
    }

    function _assessMarketRisk(uint256 /* poolId */) internal pure returns (uint256) {
        // Market conditions assessment
        return 3000; // Placeholder
    }

    function _getPoolInvestorCount(uint256 /* poolId */) internal pure returns (uint256) {
        // Count unique investors in pool
        return 0; // Placeholder - would need investor tracking
    }

    function _getInvestorPoolReturns(address /* investor */, uint256 /* poolId */) internal pure returns (uint256) {
        // Get returns for specific investor in specific pool
        return 0; // Placeholder
    }

    function _calculateInvestorPoolRoi(address investor, uint256 poolId) internal view returns (uint256) {
        uint256 investment = POOL_FUNDING_MANAGER.investorPoolInvestments(poolId, investor);
        uint256 investorReturns = _getInvestorPoolReturns(investor, poolId);
        
        if (investment == 0) return 0;
        return (investorReturns * BASIS_POINTS) / investment;
    }

    function _calculateExporterVolumes(address exporter)
        internal
        view
        returns (
            uint256 totalInvoices,
            uint256 totalValue,
            uint256 averageValue
        )
    {
        uint256 invoiceCount = INVOICE_NFT.totalSupply();
        
        for (uint256 i = 1; i <= invoiceCount; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(i);
            
            if (invoice.exporterWallet == exporter) {
                totalInvoices++;
                totalValue += invoice.shippingAmount;
            }
        }
        
        averageValue = totalInvoices > 0 ? totalValue / totalInvoices : 0;
    }

    function _calculateExporterPerformance(address exporter)
        internal
        view
        returns (
            uint256 completionRate,
            uint256 averagePaymentTime,
            uint256 defaultRate
        )
    {
        uint256 invoiceCount = INVOICE_NFT.totalSupply();
        uint256 exporterInvoices = 0;
        uint256 completedInvoices = 0;
        uint256 totalPaymentTime = 0;
        uint256 defaultedInvoices = 0;
        
        for (uint256 i = 1; i <= invoiceCount; i++) {
            InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(i);
            
            if (invoice.exporterWallet == exporter) {
                exporterInvoices++;
                
                if (invoice.status == InvoiceNFT.InvoiceStatus.Paid) {
                    completedInvoices++;
                    totalPaymentTime += 30 days; // Simplified calculation
                } else if (invoice.status == InvoiceNFT.InvoiceStatus.Cancelled) {
                    defaultedInvoices++;
                }
            }
        }
        
        completionRate = exporterInvoices > 0 ? 
            (completedInvoices * BASIS_POINTS) / exporterInvoices : 0;
        averagePaymentTime = completedInvoices > 0 ? 
            totalPaymentTime / completedInvoices : 0;
        defaultRate = exporterInvoices > 0 ? 
            (defaultedInvoices * BASIS_POINTS) / exporterInvoices : 0;
    }

    function _calculateExporterReliability(address exporter) internal view returns (uint256) {
        // Calculate based on completion rate, payment time, and default rate
        (uint256 completionRate, uint256 averagePaymentTime, uint256 defaultRate) = 
            _calculateExporterPerformance(exporter);
        
        // Higher completion rate and lower default rate = higher reliability
        uint256 baseScore = (completionRate + (BASIS_POINTS - defaultRate)) / 2;
        
        // Adjust for payment time (faster payments = higher score)
        if (averagePaymentTime <= 15 days) {
            baseScore = (baseScore * 110) / 100; // 10% bonus
        } else if (averagePaymentTime >= 45 days) {
            baseScore = (baseScore * 90) / 100; // 10% penalty
        }
        
        return baseScore > BASIS_POINTS ? BASIS_POINTS : baseScore;
    }

    function _getExporterPoolCount(address exporter) internal view returns (uint256) {
        uint256 poolCount = POOL_NFT.totalSupply();
        uint256 exporterPoolCount = 0;
        
        for (uint256 i = 1; i <= poolCount; i++) {
            uint256[] memory invoiceIds = POOL_NFT.getPoolInvoices(i);
            
            for (uint256 j = 0; j < invoiceIds.length; j++) {
                InvoiceNFT.Invoice memory invoice = INVOICE_NFT.getInvoice(invoiceIds[j]);
                if (invoice.exporterWallet == exporter) {
                    exporterPoolCount++;
                    break; // Count pool only once per exporter
                }
            }
        }
        
        return exporterPoolCount;
    }

    function _getExporterLastActivity(address /* exporter */) internal pure returns (uint256) {
        // Get timestamp of last invoice activity
        return 0; // Placeholder - would need event tracking
    }

    // Historical data calculation functions
    function _calculateCurrentVolume() internal view returns (uint256) {
        return platformMetrics.totalValueLocked;
    }

    function _calculateNewInvestments(uint256 /* dayTimestamp */) internal pure returns (uint256) {
        // Count investments made on specific day
        return 0; // Placeholder - would need event filtering
    }

    function _calculateCompletedInvoices(uint256 /* dayTimestamp */) internal pure returns (uint256) {
        // Count invoices completed on specific day
        return 0; // Placeholder - would need event filtering
    }

    function _calculateCurrentAverageRoi() internal view returns (uint256) {
        uint256 poolCount = POOL_NFT.totalSupply();
        uint256 totalRoi = 0;
        uint256 completedPools = 0;
        
        for (uint256 i = 1; i <= poolCount; i++) {
            if (poolPerformance[i].isCompleted) {
                totalRoi += poolRoi[i];
                completedPools++;
            }
        }
        
        return completedPools > 0 ? totalRoi / completedPools : 0;
    }

    function _calculatePlatformUtilization() internal view returns (uint256) {
        // Calculate platform capacity utilization
        uint256 totalCapacity = 10000000e18; // 10M tokens capacity (example)
        return (platformMetrics.totalValueLocked * BASIS_POINTS) / totalCapacity;
    }

    // ================================
    // Additional View Functions
    // ================================

    /**
     * @notice Get platform summary statistics
     * @return metrics Complete platform metrics
     */
    function getPlatformMetrics() external view returns (PlatformMetrics memory metrics) {
        return platformMetrics;
    }

    /**
     * @notice Get historical data for trend analysis
     * @param fromTimestamp Start timestamp for data range
     * @param toTimestamp End timestamp for data range
     * @return timestamps Array of data point timestamps
     * @return volumes Array of corresponding volume data
     * @return rois Array of corresponding ROI data
     */
    function getHistoricalTrends(
        uint256 fromTimestamp,
        uint256 toTimestamp
    )
        external
        view
        returns (
            uint256[] memory timestamps,
            uint256[] memory volumes,
            uint256[] memory rois
        )
    {
        if (fromTimestamp >= toTimestamp) revert InvalidTimestamp(fromTimestamp);
        
        uint256 dataPoints = ((toTimestamp - fromTimestamp) / TIME_SERIES_INTERVAL) + 1;
        timestamps = new uint256[](dataPoints);
        volumes = new uint256[](dataPoints);
        rois = new uint256[](dataPoints);
        
        uint256 currentTimestamp = fromTimestamp - (fromTimestamp % TIME_SERIES_INTERVAL);
        
        for (uint256 i = 0; i < dataPoints && currentTimestamp <= toTimestamp; i++) {
            timestamps[i] = currentTimestamp;
            
            TimeSeriesData memory data = historicalData[currentTimestamp];
            volumes[i] = data.totalVolume;
            rois[i] = data.averageRoi;
            
            currentTimestamp += TIME_SERIES_INTERVAL;
        }
    }

    /**
     * @notice Check if analytics data is stale
     * @param metricType Type of metric to check
     * @return isStale Whether data is stale
     * @return lastUpdate Timestamp of last update
     */
    function isDataStale(bytes32 metricType) 
        external 
        view 
        returns (bool isStale, uint256 lastUpdate) 
    {
        lastUpdate = lastUpdateTimestamp[metricType];
        isStale = (block.timestamp - lastUpdate) > STALENESS_THRESHOLD;
    }
}