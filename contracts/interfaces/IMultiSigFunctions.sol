// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "./ITreasuryV2.sol";
import "./ITokenCollectorV2.sol";
import "../management/CommunityManagerPayoutControllerV2.sol";

interface IMultiSigFunctions {

    enum ActionTypes {

        //Manager
        SetRequiredSignatures,
        ReplaceMemberWallet,

        //Account token
        ChangeLiquidationPeriods,

        //Registry
        SetContractAddress,
        SetMatrixAddress,
        AddMatrixLevel,
        SetLiquidityControllerAddress,
        SetBuybackControllerAddress,
        SetPriceCalcAddress,
        SetRealmGuardian,
        SetCoinMaster,

        //Reward distributor
        SetBonusActivationTimeout,

        //Collector
        SetCollectionType,
        SetPriceCalculationType,
        SetAdditionalTokensPercentage,
        SetBonusTokenPercentageFromSwap,

        //Treasury
        StartTrackingToken,
        StopTrackingToken,
        ProvideLiquidity,
        RemoveLiquidity,
        CollectLostTokensFromContract,
        Manage,
        BuyBackMETFI,
        StartLiquidation,

        PayoutCommunityManagers,

        ChangeTimeLockTime,

        // Lending
        InitializeLending,
        MigrateLending,


        // StakingPool
        SetMETFIPercentagePerPeriod,
        MigratePool,

        // Auction
        MigrateAuction,

        // NFTTransferProxy
        SetTransferFee
    }


    struct SetRequiredSignaturesRequest {
        uint256 newRequiredSignatures;
    }

    struct ReplaceAccountWalletRequest {
        address oldAddress;
        address newAddress;
    }

    struct AddManagerWalletRequest {
        address newWallet;
    }

    struct RemoveManagerWalletRequest {
        address walletToRemove;
    }

    struct ChangeApprovalLimitRequest {
        uint256 limit;
    }

    struct ChangeLiquidationPeriodsReq {
        uint256 newLiquidationGracePeriod;
        uint256 newLiquidationClaimPeriod;
    }

    struct SetContractAddressRequest {
        string name;
        address newAddress;
    }

    struct SetMatrixAddressRequest {
        uint256 level;
        address newAddress;
    }

    struct AddMatrixLevelRequest {
        address newAddress;
    }

    struct SetLiquidityControllerAddressRequest {
        string name;
        address newAddress;
    }

    struct SetBuybackControllerAddressRequest {
        string name;
        address newAddress;
    }

    struct SetPriceCalcAddressRequest {
        address currencyAddress;
        address calculatorAddress;
    }

    struct SetRealmGuardianRequest {
        address guardianAddress;
        bool approved;
    }

    struct SetCoinMasterRequest {
        address masterAddress;
        bool approved;
    }

    struct SetBonusActivationTimeoutRequest {
        uint256 newBonusActivationTimeout;
    }

    struct SetCollectionTypeRequest {
        ITokenCollectorV2.CollectionType newCollectionType;
    }

    struct SetPriceCalculationTypeRequest {
        ITokenCollectorV2.PriceCalculationType newPriceCalculationType;
    }

    struct SetAdditionalTokensPercentageRequest {
        uint256 newAdditionalTokensPercentage;
    }

    struct SetBonusTokenPercentageFromSwapRequest {
        uint256 newBonusTokenPercentageFromSwap;
    }

    struct StartTrackingTokenRequest {
        ITreasuryV2.TokenType tokenType;
        address token;
        bool isReserveToken;
        string liquidityControllerName;
    }

    struct StopTrackingTokenRequest {
        ITreasuryV2.TokenType tokenType;
        address token;
        string liquidityControllerName;
    }

    struct ProvideLiquidityRequest {
        string controllerName;
        address tokenToUse;
        uint256 amount;
        uint256 METFIMin;
    }

    struct RemoveLiquidityRequest {
        string controllerName;
        address tokenToUse;
        uint256 lpTokenAmount;
        uint256 tokenMin;
    }

    struct CollectLostTokensFromContractRequest {
        address token;
        address metFiContract;
    }

    struct ManageRequest {
        address to;
        address token;
        uint256 amount;
    }

    struct BuyBackMETFIRequest {
        string buybackControllerName;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 minMETFIOut;
    }

    struct StartLiquidationRequest {
        address payable claimEthTo;
    }


    struct PayoutCommunityManagersRequest {
        CommunityManagerPayoutControllerV2.PayoutMember[] payoutData;
    }

    struct ChangeTimeLockTimeRequest {
        uint256 newTime;
    }

    struct InitializeLendingRequest {
        address newLending;
    }

    struct MigrateLendingRequest {
        uint256 maxLoansToProcess;
        address newLending;
    }

    struct SetMETFIPercentagePerPeriodRequest {
        uint256 newPercentage;
    }

    struct MigratePoolRequest {
        address newPool;
    }

    struct MigrateAuctionRequest {
        uint256 maxAuctionsToProcess;
        address newAuction;
    }

    struct SetNFTTransferProxyFeeRequest {
        uint256 newFee;
    }

}
