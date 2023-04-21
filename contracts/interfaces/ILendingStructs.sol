// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

// @title MetFi Lending Structs
// @author MetFi
// @notice This contract is a base for all lending contracts
interface ILendingStructs {
    event LoanCreated(uint256 indexed loanId);
    event LoanLiquidated(uint256 indexed loanId);
    event LoanInvalidated(uint256 indexed loanId);
    event LoanFunded(
        uint256 indexed loanId,
        address indexed lender,
        uint256 amount
    );
    event LoanFullyFunded(uint256 indexed loanId);
    event LoanFundingRemoved(
        uint256 indexed loanId,
        address indexed lender,
        uint256 amount
    );
    event LoanRepaymentMade(uint256 indexed loanId);
    event LoanFullyRepaid(uint256 indexed loanId);
    event LoanExtensionRequested(uint256 indexed loanId);
    event LoanExtended(uint256 indexed loanId);
    event CollateralAdded(
        uint256 indexed loanId,
        address indexed currency,
        uint256 amount
    );
    event LoanMigrated(
        uint256 indexed loanId
    );

    struct LendingConfiguration {
        uint256 maxLoanDuration; // in number of seconds
        uint256 minLoanDuration; // in number of seconds
        uint256 minLoanAmount; // in SelectedStablecoin
        uint256 minFundAmount; // in SelectedStablecoin
        uint256 treasuryInterestPercentage; // 10000 = 100%
        uint256 foreignCurrencyExchangeFeePercentage; // 1_000_000 = 100%
        uint256 fundGracePeriod; // number of seconds, after which lender can remove funds from loan
        uint256 liquidationLoanPercentageOfStakedValue; // 1_000_000 = 100%
        uint256 warningLoanPercentageOfStakedValue; // 1_000_000 = 100%
        uint256 creationLoanPercentageOfStakedValue; // 1_000_000 = 100%
        uint256 liquidationGracePeriod; // number of seconds before loan can be liquidated
        uint256 maxLiquidationGracePeriod; // number of seconds after which loan can no longer be liquidated
        uint256 maxFundingWaitTime; // number of seconds after which not fully funded loan will be invalidated
        uint256 repaymentGracePeriod; // number of seconds after loan deadline, when loan can still be repaid without liquidation
        uint256 loanExtensionFeeInBNB; // Sent to loanExtensionFeeReceiver
        address payable loanExtensionFeeReceiver; // Address that receives loan extension fees
        uint256 loanLiquidationFeeInSelectedStablecoin; // Sent to loanLiquidationFeeReceiver as BNB
        address loanLiquidationFeeReceiver; // Address that receives loan liquidation fees
        uint256[] liquidationFeePayoutCurve; // in percentage points (1000 = 100%) example that follows curve (x*x)/100 : [0,0,0,0,1,2,3,4,6,8,10,12,14,16,19,22,25,28,32,36,40,44,48,52,57,62,67,72,78,84,90,96,102,108,115,122,129,136,144,152,160,168,176,184,193,202,211,220,230,240,250,260,270,280,291,302,313,324,336,348,360,372,384,396,409,422,435,448,462,476,490,504,518,532,547,562,577,592,608,624,640,656,672,688,705,722,739,756,774,792,810,828,846,864,883,902,921,940,960,980,1000]
    }

    struct CreateLoanRequest {
        uint256 duration; // in seconds
        uint256 apyPercentage; // 10000 = 100%
        uint256 tokenId;
        uint256 amount;
    }

    struct RepayLoanRequest {
        uint256 loanId;
        uint256 amount; // Max amount to repay
    }

    struct FundLoanRequest {
        uint256 loanId;
        uint256 amount; // Max amount to fund
    }

    struct ExtendLoanRequest {
        uint256 oldDeadline;
        uint256 newDeadline;
        uint256 newInterestRate;
        uint256 loanId;
        bytes[] lenderSignatures;
    }

    struct AddCollateralRequest {
        uint256 loanId;
        address currency;
        uint256 amount;
    }

    struct ExtendLoanLenderApproval {
        uint256 oldDeadline;
        uint256 newDeadline;
        uint256 newInterestRate;
        uint256 loanId;
    }

    struct EarlyLoanRepaymentClaimRequest {
        uint256 loanId;
        uint256 lenderIndex; // To avoid gas fees
    }

    struct LoanInfo {
        uint256 loanId;
        uint256 tokenId;
        uint256 apy;
        uint256 amount;
        address borrower;
        uint256 duration;
        uint256 deadline;
        uint256 amountFunded; // Amount funded by lenders
        uint256 repaidAmount; // Amount repaid by borrower
        uint256 totalInterest;
        uint256 creationTimestamp;
        uint256 liquidationTimestamp;
        uint256 fundedTimestamp;
        uint256 repaidTimestamp;
        uint256 totalRewardsAtLastRepaymentTime; // Or at funded time if no repayment has been made
        LoanStage stage;
        LenderInfo[] lenderInfo;
        address[] additionalCollateralAddresses; // additional collateral for loan
        uint256[] additionalCollateralAmounts; // additional collateral for loan
    }

    struct LenderInfo {
        address lender;
        uint256 shareOfLoan; // Percentage of loan funded by lender 100 % = 100_000_000
        uint256 lastFundingTimestamp;
    }

    struct LiquidationData {
        uint256 totalMETFIInLiquidation;
        uint256 METFIIn;
        uint256 SelectedStablecoinFromMETFI;
        uint256[] collateralIn;
        uint256[] collateralForTreasury;
        uint256[] SelectedStablecoinFromCollateralLiquidation;
        uint256[] lenderPayouts;
    }

    enum LoanStage {
        Created, // Create by borrower
        Funded, // Completely funded by lenders
        Repaid, // Repaid by borrower. All lenders have been repaid and received their interest
        Liquidated, // Liquidated by the protocol. All lenders have been repaid and received their interest in proportion to the start time of the loan
        Invalidated, // Invalidated by the lender
        Migrated // Migrated to a new contract
    }

    // Access Control
    error OnlyLendingManager();
    error BlacklistedAddress();
    error OnlyLender();
    error OnlyMetFiNFT();

    // Extend
    error NotBorrower();
    error InvalidLenderSignatureCount();
    error LoanExtensionNotRequested();
    error InvalidLoanExtensionRequest();

    // Create
    error NotTokenOwner();
    error LoanAmountTooLow();
    error LoanDurationTooLong();
    error NotEnoughCollateral();
    error LoanDurationTooShort();
    error LoanCreationNotAllowed();
    error NFTInLiquidation();
    error NFTInLiquidated();
    error OnlyOneActiveLoanPerNFT();

    // Common
    error NotApproved();
    error InsufficientBalance();
    error LoanNotInFundedStage();
    error InsufficientAllowance();
    error LoanDoesNotExist();
    error FailsafeEnabled();
    error NotInitialized();
    error AlreadyInitialized();
    error MoreThanNeededAlreadyRepaid();

    // Migration
    error LendingNotDisabledBeforeMigration();
    error MigrationAlreadyFinished();

    // Fund
    error AmountTooLow();
    error LenderNotFound();
    error FundAmountTooLow();
    error LoanNotInCreatedStage();
    error CannotFundOwnLoan();
    error FundingTimeExpired();
    error CannotRemoveFundingBeforeGracePeriod(uint256 timestamp);
    error LoanExtensionFeeTooLow();

    // Collateral
    error CollateralCurrencyNotApproved();

    // Lending Configuration
    error InvalidAddress();
    error InvalidLoanDurationConfig();
    error InvalidLiquidationGracePeriod();
    error InvalidLiquidationFeePayoutCurve();
    error InvalidLoanPercentageOfStakedValue();

    // Migration
    error InvalidToken();
    error LoanAlreadyExists();
    error InvalidSender();
}
