// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {InvoiceNFT} from "../src/InvoiceNFT.sol";
import {PlatformAccessControl} from "../src/AccessControl.sol";

/**
 * @title InvoiceNFT Test Suite
 * @notice Comprehensive test suite for the InvoiceNFT contract
 * @dev Tests all functionality including minting, funding, withdrawals, and status transitions
 */
contract InvoiceNFTTest is Test {
    // Test contracts
    PlatformAccessControl public accessControl;
    InvoiceNFT public invoiceNft;
    
    // Test addresses
    address public admin = makeAddr("admin");
    address public exporter1 = makeAddr("exporter1");
    address public exporter2 = makeAddr("exporter2");
    address public investor1 = makeAddr("investor1");
    address public investor2 = makeAddr("investor2");
    address public nonUser = makeAddr("nonUser");
    
    // Test constants
    uint256 constant SAMPLE_SHIPPING_AMOUNT = 100000e18; // $100k
    uint256 constant SAMPLE_LOAN_AMOUNT = 70000e18; // $70k (70% of shipping)
    uint256 constant SAMPLE_SHIPPING_DATE = 1700000000; // Nov 14, 2023
    string constant SAMPLE_EXPORTER = "Global Exports Ltd";
    string constant SAMPLE_IMPORTER = "Import Solutions Inc";
    
    // Events for testing
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
        InvoiceNFT.InvoiceStatus previousStatus,
        InvoiceNFT.InvoiceStatus newStatus
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

    /**
     * @notice Set up test environment
     */
    function setUp() public {
        // Deploy contracts
        vm.startPrank(admin);
        accessControl = new PlatformAccessControl(admin);
        invoiceNft = new InvoiceNFT(address(accessControl));
        
        // Setup roles
        accessControl.grantExporterRole(exporter1);
        accessControl.grantExporterRole(exporter2);
        accessControl.grantInvestorRole(investor1);
        accessControl.grantInvestorRole(investor2);
        
        vm.stopPrank();
    }

    // ================================
    // Constructor Tests
    // ================================
    
    function test_Constructor_Success() public view {
        assertEq(address(invoiceNft.ACCESS_CONTROL()), address(accessControl));
        assertEq(invoiceNft.name(), "Shipping Invoice NFT");
        assertEq(invoiceNft.symbol(), "INVOICE");
        assertEq(invoiceNft.totalSupply(), 0);
        assertEq(invoiceNft.totalLoanAmount(), 0);
        assertEq(invoiceNft.totalInvestedAmount(), 0);
    }
    
    function test_Constructor_RevertZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidAddress.selector, address(0)));
        new InvoiceNFT(address(0));
    }

    // ================================
    // Invoice Minting Tests
    // ================================
    
    function test_MintInvoice_Success() public {
        vm.startPrank(exporter1);
        
        vm.expectEmit(true, true, false, true);
        emit InvoiceMinted(
            1,
            exporter1,
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        assertEq(invoiceId, 1);
        assertEq(invoiceNft.ownerOf(1), exporter1);
        assertEq(invoiceNft.totalSupply(), 1);
        assertEq(invoiceNft.totalLoanAmount(), SAMPLE_LOAN_AMOUNT);
        
        // Check invoice details
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(1);
        assertEq(invoice.exporterWallet, exporter1);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Pending));
        assertEq(invoice.shippingAmount, SAMPLE_SHIPPING_AMOUNT);
        assertEq(invoice.loanAmount, SAMPLE_LOAN_AMOUNT);
        assertEq(invoice.amountInvested, 0);
        assertEq(invoice.amountWithdrawn, 0);
        assertEq(invoice.shippingDate, SAMPLE_SHIPPING_DATE);
        assertEq(invoice.exporterCompany, SAMPLE_EXPORTER);
        assertEq(invoice.importerCompany, SAMPLE_IMPORTER);
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_RevertNotExporter() public {
        vm.startPrank(nonUser);
        
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotExporter.selector, nonUser));
        invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_RevertZeroShippingAmount() public {
        vm.startPrank(exporter1);
        
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidAmount.selector, 0));
        invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            0,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_RevertZeroLoanAmount() public {
        vm.startPrank(exporter1);
        
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidAmount.selector, 0));
        invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            0,
            SAMPLE_SHIPPING_DATE
        );
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_RevertLoanExceedsShipping() public {
        vm.startPrank(exporter1);
        
        uint256 invalidLoanAmount = SAMPLE_SHIPPING_AMOUNT + 1;
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidAmount.selector, invalidLoanAmount));
        invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            invalidLoanAmount,
            SAMPLE_SHIPPING_DATE
        );
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_RevertZeroShippingDate() public {
        vm.startPrank(exporter1);
        
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidShippingDate.selector, 0));
        invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            0
        );
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_RevertEmptyExporterCompany() public {
        vm.startPrank(exporter1);
        
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidAddress.selector, address(0)));
        invoiceNft.mintInvoice(
            "",
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_RevertEmptyImporterCompany() public {
        vm.startPrank(exporter1);
        
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidAddress.selector, address(0)));
        invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            "",
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        vm.stopPrank();
    }
    
    function test_MintInvoice_MultipleInvoices() public {
        vm.startPrank(exporter1);
        
        // Mint first invoice
        uint256 id1 = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        // Mint second invoice
        uint256 id2 = invoiceNft.mintInvoice(
            "Another Exporter",
            "Another Importer",
            50000e18,
            35000e18,
            SAMPLE_SHIPPING_DATE + 1000
        );
        
        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(invoiceNft.totalSupply(), 2);
        assertEq(invoiceNft.totalLoanAmount(), SAMPLE_LOAN_AMOUNT + 35000e18);
        
        vm.stopPrank();
    }

    // ================================
    // Invoice Finalization Tests
    // ================================
    
    function test_FinalizeInvoice_Success() public {
        // Setup: mint invoice
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        vm.expectEmit(true, false, false, true);
        emit InvoiceStatusUpdated(
            invoiceId,
            InvoiceNFT.InvoiceStatus.Pending,
            InvoiceNFT.InvoiceStatus.Finalized
        );
        
        invoiceNft.finalizeInvoice(invoiceId);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Finalized));
        
        vm.stopPrank();
    }
    
    function test_FinalizeInvoice_RevertNotOwner() public {
        // Setup: mint invoice as exporter1
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        vm.stopPrank();
        
        // Try to finalize as exporter2
        vm.startPrank(exporter2);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAuthorized.selector, exporter2));
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
    }
    
    function test_FinalizeInvoice_RevertInvalidStatus() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        // Finalize first time
        invoiceNft.finalizeInvoice(invoiceId);
        
        // Try to finalize again
        vm.expectRevert(abi.encodeWithSelector(
            InvoiceNFT.InvalidStatus.selector,
            InvoiceNFT.InvoiceStatus.Finalized,
            InvoiceNFT.InvoiceStatus.Pending
        ));
        invoiceNft.finalizeInvoice(invoiceId);
        
        vm.stopPrank();
    }

    // ================================
    // Invoice Cancellation Tests
    // ================================
    
    function test_CancelInvoice_Success() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        uint256 initialTotalLoan = invoiceNft.totalLoanAmount();
        
        vm.expectEmit(true, false, false, true);
        emit InvoiceStatusUpdated(
            invoiceId,
            InvoiceNFT.InvoiceStatus.Pending,
            InvoiceNFT.InvoiceStatus.Cancelled
        );
        
        invoiceNft.cancelInvoice(invoiceId);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Cancelled));
        assertEq(invoiceNft.totalLoanAmount(), initialTotalLoan - SAMPLE_LOAN_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_CancelInvoice_RevertNotOwner() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        vm.stopPrank();
        
        vm.startPrank(exporter2);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAuthorized.selector, exporter2));
        invoiceNft.cancelInvoice(invoiceId);
        vm.stopPrank();
    }
    
    function test_CancelInvoice_RevertAlreadyFinalized() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        invoiceNft.finalizeInvoice(invoiceId);
        
        vm.expectRevert(abi.encodeWithSelector(
            InvoiceNFT.InvalidStatus.selector,
            InvoiceNFT.InvoiceStatus.Finalized,
            InvoiceNFT.InvoiceStatus.Pending
        ));
        invoiceNft.cancelInvoice(invoiceId);
        
        vm.stopPrank();
    }

    // ================================
    // Funding Tests
    // ================================
    
    function test_AddFunding_Success() public {
        // Setup: mint and finalize invoice
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Add funding as admin
        vm.startPrank(admin);
        uint256 fundingAmount = 30000e18; // $30k
        
        vm.expectEmit(true, false, false, true);
        emit InvoiceFunded(invoiceId, fundingAmount, fundingAmount);
        
        invoiceNft.addFunding(invoiceId, fundingAmount);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Fundraising));
        assertEq(invoice.amountInvested, fundingAmount);
        assertEq(invoiceNft.totalInvestedAmount(), fundingAmount);
        
        vm.stopPrank();
    }
    
    function test_AddFunding_StatusChangeToFunded() public {
        // Setup: mint and finalize invoice
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Add funding to reach 70% threshold
        vm.startPrank(admin);
        uint256 fundingAmount = (SAMPLE_LOAN_AMOUNT * 7000) / 10000; // Exactly 70%
        
        vm.expectEmit(true, false, false, true);
        emit InvoiceStatusUpdated(
            invoiceId,
            InvoiceNFT.InvoiceStatus.Fundraising,
            InvoiceNFT.InvoiceStatus.Funded
        );
        
        invoiceNft.addFunding(invoiceId, fundingAmount);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Funded));
        assertTrue(invoiceNft.isEligibleForWithdrawal(invoiceId));
        
        vm.stopPrank();
    }
    
    function test_AddFunding_RevertNotAdmin() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(investor1);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAdmin.selector, investor1));
        invoiceNft.addFunding(invoiceId, 10000e18);
        vm.stopPrank();
    }
    
    function test_AddFunding_RevertExceedsLoanAmount() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 excessiveAmount = SAMPLE_LOAN_AMOUNT + 1;
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidAmount.selector, excessiveAmount));
        invoiceNft.addFunding(invoiceId, excessiveAmount);
        vm.stopPrank();
    }
    
    function test_AddFunding_RevertInvalidStatus() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        // Don't finalize - leave in pending state
        vm.stopPrank();
        
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(
            InvoiceNFT.InvalidStatus.selector,
            InvoiceNFT.InvoiceStatus.Pending,
            InvoiceNFT.InvoiceStatus.Finalized
        ));
        invoiceNft.addFunding(invoiceId, 10000e18);
        vm.stopPrank();
    }

    // ================================
    // Withdrawal Tests
    // ================================
    
    function test_WithdrawFunds_Success() public {
        // Setup: mint, finalize, and fund invoice to 70%
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 fundingAmount = (SAMPLE_LOAN_AMOUNT * 8000) / 10000; // 80%
        invoiceNft.addFunding(invoiceId, fundingAmount);
        vm.stopPrank();
        
        // Withdraw partial amount
        vm.startPrank(exporter1);
        uint256 withdrawAmount = 20000e18; // $20k
        
        vm.expectEmit(true, true, false, true);
        emit InvoiceWithdrawal(invoiceId, exporter1, withdrawAmount, fundingAmount - withdrawAmount);
        
        invoiceNft.withdrawFunds(invoiceId, withdrawAmount);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(invoice.amountWithdrawn, withdrawAmount);
        assertEq(invoiceNft.getAvailableWithdrawal(invoiceId), fundingAmount - withdrawAmount);
        
        vm.stopPrank();
    }
    
    function test_WithdrawFunds_WithdrawAll() public {
        // Setup funding
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 fundingAmount = SAMPLE_LOAN_AMOUNT; // 100%
        invoiceNft.addFunding(invoiceId, fundingAmount);
        vm.stopPrank();
        
        // Withdraw all (amount = 0)
        vm.startPrank(exporter1);
        invoiceNft.withdrawFunds(invoiceId, 0);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(invoice.amountWithdrawn, fundingAmount);
        assertEq(invoiceNft.getAvailableWithdrawal(invoiceId), 0);
        
        vm.stopPrank();
    }
    
    function test_WithdrawFunds_RevertNotOwner() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        invoiceNft.addFunding(invoiceId, SAMPLE_LOAN_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(exporter2);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAuthorized.selector, exporter2));
        invoiceNft.withdrawFunds(invoiceId, 10000e18);
        vm.stopPrank();
    }
    
    function test_WithdrawFunds_RevertInsufficientFunding() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Fund only 50% (below 70% threshold)
        vm.startPrank(admin);
        uint256 fundingAmount = (SAMPLE_LOAN_AMOUNT * 5000) / 10000; // 50%
        invoiceNft.addFunding(invoiceId, fundingAmount);
        vm.stopPrank();
        
        vm.startPrank(exporter1);
        uint256 requiredAmount = (SAMPLE_LOAN_AMOUNT * 7000) / 10000;
        vm.expectRevert(abi.encodeWithSelector(
            InvoiceNFT.InsufficientFunding.selector,
            fundingAmount,
            requiredAmount
        ));
        invoiceNft.withdrawFunds(invoiceId, 10000e18);
        vm.stopPrank();
    }
    
    function test_WithdrawFunds_RevertExceedsAvailable() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 fundingAmount = (SAMPLE_LOAN_AMOUNT * 8000) / 10000; // 80%
        invoiceNft.addFunding(invoiceId, fundingAmount);
        vm.stopPrank();
        
        vm.startPrank(exporter1);
        uint256 excessiveAmount = fundingAmount + 1;
        vm.expectRevert(abi.encodeWithSelector(
            InvoiceNFT.WithdrawalExceedsAvailable.selector,
            excessiveAmount,
            fundingAmount
        ));
        invoiceNft.withdrawFunds(invoiceId, excessiveAmount);
        vm.stopPrank();
    }

    // ================================
    // Payment Confirmation Tests
    // ================================
    
    function test_ConfirmPayment_Success() public {
        // Setup funded invoice
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        invoiceNft.addFunding(invoiceId, SAMPLE_LOAN_AMOUNT);
        
        vm.expectEmit(true, false, false, true);
        emit InvoiceStatusUpdated(
            invoiceId,
            InvoiceNFT.InvoiceStatus.Funded,
            InvoiceNFT.InvoiceStatus.Paid
        );
        
        invoiceNft.confirmPayment(invoiceId);
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Paid));
        
        vm.stopPrank();
    }
    
    function test_ConfirmPayment_RevertNotAdmin() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        invoiceNft.addFunding(invoiceId, SAMPLE_LOAN_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(exporter1);
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.NotAdmin.selector, exporter1));
        invoiceNft.confirmPayment(invoiceId);
        vm.stopPrank();
    }

    // ================================
    // View Functions Tests
    // ================================
    
    function test_GetInvoice_Success() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        
        assertEq(invoice.exporterWallet, exporter1);
        assertEq(uint8(invoice.status), uint8(InvoiceNFT.InvoiceStatus.Pending));
        assertEq(invoice.shippingAmount, SAMPLE_SHIPPING_AMOUNT);
        assertEq(invoice.loanAmount, SAMPLE_LOAN_AMOUNT);
        assertEq(invoice.exporterCompany, SAMPLE_EXPORTER);
        assertEq(invoice.importerCompany, SAMPLE_IMPORTER);
        assertEq(invoice.shippingDate, SAMPLE_SHIPPING_DATE);
        
        vm.stopPrank();
    }
    
    function test_GetInvoice_RevertInvalidId() public {
        vm.expectRevert(abi.encodeWithSelector(InvoiceNFT.InvalidInvoiceId.selector, 999));
        invoiceNft.getInvoice(999);
    }
    
    function test_IsEligibleForWithdrawal() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Not eligible before funding
        assertFalse(invoiceNft.isEligibleForWithdrawal(invoiceId));
        
        // Fund to 60% - not eligible
        vm.startPrank(admin);
        uint256 fundingAmount1 = (SAMPLE_LOAN_AMOUNT * 6000) / 10000; // 60%
        invoiceNft.addFunding(invoiceId, fundingAmount1);
        assertFalse(invoiceNft.isEligibleForWithdrawal(invoiceId));
        
        // Add more to reach 75% - eligible
        uint256 fundingAmount2 = (SAMPLE_LOAN_AMOUNT * 1500) / 10000; // 15% more
        invoiceNft.addFunding(invoiceId, fundingAmount2);
        assertTrue(invoiceNft.isEligibleForWithdrawal(invoiceId));
        
        vm.stopPrank();
    }
    
    function test_GetFundingProgress() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        // Initial progress
        (uint256 funded, uint256 total, uint256 percentage) = invoiceNft.getFundingProgress(invoiceId);
        assertEq(funded, 0);
        assertEq(total, SAMPLE_LOAN_AMOUNT);
        assertEq(percentage, 0);
        
        // After funding 40%
        vm.startPrank(admin);
        uint256 fundingAmount = (SAMPLE_LOAN_AMOUNT * 4000) / 10000; // 40%
        invoiceNft.addFunding(invoiceId, fundingAmount);
        
        (funded, total, percentage) = invoiceNft.getFundingProgress(invoiceId);
        assertEq(funded, fundingAmount);
        assertEq(total, SAMPLE_LOAN_AMOUNT);
        assertEq(percentage, 4000); // 40% in basis points
        
        vm.stopPrank();
    }
    
    function test_GetInvoicesByStatus() public {
        // Create invoices with different statuses
        vm.startPrank(exporter1);
        uint256 id1 = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        uint256 id2 = invoiceNft.mintInvoice(
            "Company 2",
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        invoiceNft.finalizeInvoice(id2);
        vm.stopPrank();
        
        // Test filtering
        uint256[] memory pendingInvoices = invoiceNft.getInvoicesByStatus(InvoiceNFT.InvoiceStatus.Pending);
        uint256[] memory finalizedInvoices = invoiceNft.getInvoicesByStatus(InvoiceNFT.InvoiceStatus.Finalized);
        
        assertEq(pendingInvoices.length, 1);
        assertEq(pendingInvoices[0], id1);
        
        assertEq(finalizedInvoices.length, 1);
        assertEq(finalizedInvoices[0], id2);
    }
    
    function test_GetInvoicesByExporter() public {
        vm.startPrank(exporter1);
        uint256 id1 = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        
        uint256 id2 = invoiceNft.mintInvoice(
            "Another Company",
            SAMPLE_IMPORTER,
            50000e18,
            35000e18,
            SAMPLE_SHIPPING_DATE
        );
        vm.stopPrank();
        
        vm.startPrank(exporter2);
        uint256 id3 = invoiceNft.mintInvoice(
            "Exporter 2 Company",
            SAMPLE_IMPORTER,
            30000e18,
            20000e18,
            SAMPLE_SHIPPING_DATE
        );
        vm.stopPrank();
        
        // Test filtering by exporter
        uint256[] memory exporter1Invoices = invoiceNft.getInvoicesByExporter(exporter1);
        uint256[] memory exporter2Invoices = invoiceNft.getInvoicesByExporter(exporter2);
        
        assertEq(exporter1Invoices.length, 2);
        assertEq(exporter1Invoices[0], id1);
        assertEq(exporter1Invoices[1], id2);
        
        assertEq(exporter2Invoices.length, 1);
        assertEq(exporter2Invoices[0], id3);
    }
    
    function test_GetPlatformStats() public {
        // Initial stats
        (uint256 totalInvoices, uint256 totalLoan, uint256 totalInvested) = invoiceNft.getPlatformStats();
        assertEq(totalInvoices, 0);
        assertEq(totalLoan, 0);
        assertEq(totalInvested, 0);
        
        // After creating and funding invoices
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 fundingAmount = 30000e18;
        invoiceNft.addFunding(invoiceId, fundingAmount);
        vm.stopPrank();
        
        (totalInvoices, totalLoan, totalInvested) = invoiceNft.getPlatformStats();
        assertEq(totalInvoices, 1);
        assertEq(totalLoan, SAMPLE_LOAN_AMOUNT);
        assertEq(totalInvested, fundingAmount);
    }

    // ================================
    // Edge Cases and Stress Tests
    // ================================
    
    function test_MaxValues() public {
        vm.startPrank(exporter1);
        
        // Test maximum allowed values that are valid within business constraints
        uint256 maxShipping = type(uint88).max; // Max shipping amount that fits in uint88
        uint256 maxLoan = maxShipping; // Loan can't exceed shipping amount
        uint256 maxDate = type(uint64).max; // Max date that fits in uint64
        
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            maxShipping,
            maxLoan,
            maxDate
        );
        
        InvoiceNFT.Invoice memory invoice = invoiceNft.getInvoice(invoiceId);
        assertEq(invoice.shippingAmount, maxShipping);
        assertEq(invoice.loanAmount, maxLoan);
        assertEq(invoice.shippingDate, maxDate);
        
        vm.stopPrank();
    }
    
    function test_BoundaryFundingThreshold() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        // Test exactly 70% - should be eligible
        uint256 exactThreshold = (SAMPLE_LOAN_AMOUNT * 7000) / 10000;
        invoiceNft.addFunding(invoiceId, exactThreshold);
        assertTrue(invoiceNft.isEligibleForWithdrawal(invoiceId));
        
        vm.stopPrank();
    }
    
    function test_ZeroWithdrawalAmount() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 fundingAmount = SAMPLE_LOAN_AMOUNT;
        invoiceNft.addFunding(invoiceId, fundingAmount);
        vm.stopPrank();
        
        // Withdraw all by passing 0
        vm.startPrank(exporter1);
        invoiceNft.withdrawFunds(invoiceId, 0);
        
        assertEq(invoiceNft.getAvailableWithdrawal(invoiceId), 0);
        vm.stopPrank();
    }

    // ================================
    // Gas Usage Tests
    // ================================
    
    function test_GasUsage_MintInvoice() public {
        vm.startPrank(exporter1);
        
        uint256 gasBefore = gasleft();
        invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for mintInvoice:", gasUsed);
        // Should be reasonable for complex NFT creation with storage optimization
        assertTrue(gasUsed < 350000);
        
        vm.stopPrank();
    }
    
    function test_GasUsage_AddFunding() public {
        vm.startPrank(exporter1);
        uint256 invoiceId = invoiceNft.mintInvoice(
            SAMPLE_EXPORTER,
            SAMPLE_IMPORTER,
            SAMPLE_SHIPPING_AMOUNT,
            SAMPLE_LOAN_AMOUNT,
            SAMPLE_SHIPPING_DATE
        );
        invoiceNft.finalizeInvoice(invoiceId);
        vm.stopPrank();
        
        vm.startPrank(admin);
        uint256 gasBefore = gasleft();
        invoiceNft.addFunding(invoiceId, 30000e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for addFunding:", gasUsed);
        assertTrue(gasUsed < 100000);
        
        vm.stopPrank();
    }
}