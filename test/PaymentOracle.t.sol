// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/AccessControl.sol";
import "../src/InvoiceNFT.sol";
import "../src/PoolNFT.sol";
import "../src/PoolFundingManager.sol";
import "../src/PaymentOracle.sol";

contract PaymentOracleTest is Test {
    PlatformAccessControl accessControl;
    InvoiceNFT invoiceNft;
    PoolNFT poolNft;
    PoolFundingManager fundingManager;
    PaymentOracle paymentOracle;

    address admin = makeAddr("admin");
    address oracle1 = makeAddr("oracle1");
    address oracle2 = makeAddr("oracle2");
    address exporter = makeAddr("exporter");
    address investor = makeAddr("investor");

    uint256 sampleInvoiceId;
    uint256 samplePoolId;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        poolNft = new PoolNFT(address(accessControl), address(invoiceNft));
        fundingManager = new PoolFundingManager(
            address(accessControl),
            address(invoiceNft),
            address(poolNft)
        );
        paymentOracle = new PaymentOracle(
            address(accessControl),
            address(invoiceNft),
            address(poolNft),
            address(fundingManager)
        );

        // Setup roles
        accessControl.grantExporterRole(exporter);
        accessControl.grantInvestorRole(investor);
        accessControl.grantAdminRole(address(fundingManager));

        // Authorize oracles
        paymentOracle.authorizeOracle(oracle1);
        paymentOracle.authorizeOracle(oracle2);

        vm.stopPrank();

        // Create test data
        _createTestData();
    }

    function _createTestData() internal {
        // Create invoice
        vm.startPrank(exporter);
        sampleInvoiceId = invoiceNft.mintInvoice(
            "Test Exporter",
            "Test Importer", 
            100e18, // shipping amount
            70e18,  // loan amount
            block.timestamp + 30 days
        );
        invoiceNft.finalizeInvoice(sampleInvoiceId);
        vm.stopPrank();

        // Create pool
        vm.startPrank(admin);
        uint256[] memory invoiceIds = new uint256[](1);
        invoiceIds[0] = sampleInvoiceId;
        samplePoolId = poolNft.createPool("Test Pool", invoiceIds);
        poolNft.finalizePool(samplePoolId);
        vm.stopPrank();

        // Fund the pool
        vm.startPrank(investor);
        fundingManager.investInPool(samplePoolId, 70e18);
        vm.stopPrank();

        // Allocate funds
        vm.startPrank(admin);
        fundingManager.allocateFundsToInvoices(samplePoolId);
        vm.stopPrank();
    }

    // ================================
    // Constructor Tests
    // ================================

    function test_Constructor_Success() public view {
        assertEq(address(paymentOracle.ACCESS_CONTROL()), address(accessControl));
        assertEq(address(paymentOracle.INVOICE_NFT()), address(invoiceNft));
        assertEq(address(paymentOracle.POOL_NFT()), address(poolNft));
        assertEq(address(paymentOracle.POOL_FUNDING_MANAGER()), address(fundingManager));
    }

    function test_Constructor_RevertZeroAddress() public {
        vm.expectRevert(PaymentOracle.ZeroAddress.selector);
        new PaymentOracle(address(0), address(invoiceNft), address(poolNft), address(fundingManager));

        vm.expectRevert(PaymentOracle.ZeroAddress.selector);
        new PaymentOracle(address(accessControl), address(0), address(poolNft), address(fundingManager));

        vm.expectRevert(PaymentOracle.ZeroAddress.selector);
        new PaymentOracle(address(accessControl), address(invoiceNft), address(0), address(fundingManager));

        vm.expectRevert(PaymentOracle.ZeroAddress.selector);
        new PaymentOracle(address(accessControl), address(invoiceNft), address(poolNft), address(0));
    }

    // ================================
    // Oracle Management Tests
    // ================================

    function test_AuthorizeOracle_Success() public {
        vm.startPrank(admin);
        
        address newOracle = makeAddr("newOracle");
        paymentOracle.authorizeOracle(newOracle);
        
        assertTrue(paymentOracle.isAuthorizedOracle(newOracle));
        vm.stopPrank();
    }

    function test_AuthorizeOracle_RevertNotAdmin() public {
        vm.startPrank(exporter);
        
        vm.expectRevert(abi.encodeWithSelector(
            PaymentOracle.NotAdmin.selector,
            exporter
        ));
        paymentOracle.authorizeOracle(makeAddr("newOracle"));
        
        vm.stopPrank();
    }

    function test_RevokeOracle_Success() public {
        vm.startPrank(admin);
        
        paymentOracle.revokeOracle(oracle1);
        
        assertFalse(paymentOracle.isAuthorizedOracle(oracle1));
        vm.stopPrank();
    }

    // ================================
    // Payment Confirmation Tests
    // ================================

    function test_SubmitPaymentConfirmation_Success() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        vm.startPrank(oracle1);
        
        paymentOracle.submitPaymentConfirmation(
            sampleInvoiceId,
            paymentHash,
            amountPaid
        );

        PaymentOracle.PaymentRecord memory record = paymentOracle.getPaymentRecord(sampleInvoiceId);
        assertEq(record.paymentHash, paymentHash);
        assertEq(record.amountPaid, amountPaid);
        assertEq(record.confirmationCount, 1);
        assertFalse(record.isConfirmed);
        
        vm.stopPrank();
    }

    function test_SubmitPaymentConfirmation_MultipleOracles() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        // First oracle confirms
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(
            sampleInvoiceId,
            paymentHash,
            amountPaid
        );
        vm.stopPrank();

        // Second oracle confirms
        vm.startPrank(oracle2);
        paymentOracle.submitPaymentConfirmation(
            sampleInvoiceId,
            paymentHash,
            amountPaid
        );
        vm.stopPrank();

        // Should be confirmed now
        PaymentOracle.PaymentRecord memory record = paymentOracle.getPaymentRecord(sampleInvoiceId);
        assertEq(record.confirmationCount, 2);
        assertTrue(record.isConfirmed);
        
        // Check invoice status updated
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(sampleInvoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
    }

    function test_SubmitPaymentConfirmation_RevertNotAuthorized() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        vm.startPrank(exporter);
        
        vm.expectRevert(abi.encodeWithSelector(
            PaymentOracle.NotAuthorizedOracle.selector,
            exporter
        ));
        paymentOracle.submitPaymentConfirmation(
            sampleInvoiceId,
            paymentHash,
            amountPaid
        );
        
        vm.stopPrank();
    }

    function test_SubmitPaymentConfirmation_RevertAmountMismatch() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 wrongAmount = 50e18; // Should be 100e18

        vm.startPrank(oracle1);
        
        vm.expectRevert(abi.encodeWithSelector(
            PaymentOracle.PaymentAmountMismatch.selector,
            100e18,
            wrongAmount
        ));
        paymentOracle.submitPaymentConfirmation(
            sampleInvoiceId,
            paymentHash,
            wrongAmount
        );
        
        vm.stopPrank();
    }

    function test_SubmitPaymentConfirmation_RevertAlreadyConfirmed() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        // Confirm payment with both oracles
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();

        vm.startPrank(oracle2);
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();

        // Try to submit again
        vm.startPrank(oracle1);
        vm.expectRevert(abi.encodeWithSelector(
            PaymentOracle.PaymentAlreadyConfirmed.selector,
            sampleInvoiceId
        ));
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();
    }

    // ================================
    // Pool Settlement Tests
    // ================================

    function test_PoolSettlement_Success() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        // Confirm payment with both oracles
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();

        vm.startPrank(oracle2);
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();

        // Check that pool settlement was triggered
        assertTrue(paymentOracle.poolsPendingSettlement(samplePoolId));
        
        // Check pool status
        PoolNFT.Pool memory pool = poolNft.getPool(samplePoolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Settling));
    }

    function test_ManualSettlement_Success() public {
        // First confirm all payments manually through InvoiceNFT
        vm.startPrank(admin);
        invoiceNft.confirmPayment(sampleInvoiceId);
        
        // Then trigger manual settlement
        paymentOracle.manualSettlement(samplePoolId);
        
        // Check settlement was triggered
        assertTrue(paymentOracle.poolsPendingSettlement(samplePoolId));
        
        PoolNFT.Pool memory pool = poolNft.getPool(samplePoolId);
        assertEq(uint8(pool.status), uint8(PoolNFT.PoolStatus.Settling));
        
        vm.stopPrank();
    }

    function test_ManualSettlement_RevertNotAdmin() public {
        vm.startPrank(exporter);
        
        vm.expectRevert(abi.encodeWithSelector(
            PaymentOracle.NotAdmin.selector,
            exporter
        ));
        paymentOracle.manualSettlement(samplePoolId);
        
        vm.stopPrank();
    }

    function test_ManualSettlement_RevertPoolNotReady() public {
        vm.startPrank(admin);
        
        vm.expectRevert(abi.encodeWithSelector(
            PaymentOracle.PoolNotReadyForSettlement.selector,
            samplePoolId
        ));
        paymentOracle.manualSettlement(samplePoolId);
        
        vm.stopPrank();
    }

    // ================================
    // Dispute Management Tests  
    // ================================

    function test_DisputePayment_Success() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        // Submit payment confirmation
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();

        // Dispute the payment
        vm.startPrank(admin);
        paymentOracle.disputePayment(sampleInvoiceId, paymentHash);
        
        PaymentOracle.PaymentRecord memory record = paymentOracle.getPaymentRecord(sampleInvoiceId);
        assertTrue(record.isDisputed);
        
        vm.stopPrank();
    }

    function test_ResolvePaymentDispute_Valid() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        // Submit and dispute payment
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();

        vm.startPrank(admin);
        paymentOracle.disputePayment(sampleInvoiceId, paymentHash);
        
        // Resolve as valid
        paymentOracle.resolvePaymentDispute(sampleInvoiceId, true);
        
        PaymentOracle.PaymentRecord memory record = paymentOracle.getPaymentRecord(sampleInvoiceId);
        assertFalse(record.isDisputed);
        
        vm.stopPrank();
    }

    function test_ResolvePaymentDispute_Invalid() public {
        bytes32 paymentHash = keccak256("test_payment_123");
        uint256 amountPaid = 100e18;

        // Submit and dispute payment
        vm.startPrank(oracle1);
        paymentOracle.submitPaymentConfirmation(sampleInvoiceId, paymentHash, amountPaid);
        vm.stopPrank();

        vm.startPrank(admin);
        paymentOracle.disputePayment(sampleInvoiceId, paymentHash);
        
        // Resolve as invalid
        paymentOracle.resolvePaymentDispute(sampleInvoiceId, false);
        
        // Payment record should be reset
        PaymentOracle.PaymentRecord memory record = paymentOracle.getPaymentRecord(sampleInvoiceId);
        assertEq(record.paymentHash, bytes32(0));
        assertEq(record.amountPaid, 0);
        
        vm.stopPrank();
    }
}