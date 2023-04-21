// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../AccountToken.sol";
import "../RewardDistributor.sol";
import "../TokenCollector.sol";
import "../interfaces/ITokenCollector.sol";
import "../Treasury.sol";
import "../TreasuryExtender.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../ContractRegistry.sol";
import "./CommunityManagerPayoutController.sol";

contract MultiSigMetFiManagerV2 is EIP712 {

    using Counters for Counters.Counter;

    event ActionQueued(uint256 indexed actionType, uint256 indexed actionId, string requestId, bytes data, uint256 executionAvailableAt);
    event ActionExecuted(uint256 indexed actionType, uint256 indexed actionId, string requestId, bytes data);

    ContractRegistry contractRegistry;
    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));
    bytes32 constant TOKEN_COLLECTOR_HASH = keccak256(abi.encodePacked('token_collector'));
    bytes32 constant REWARD_DISTRIBUTOR_HASH = keccak256(abi.encodePacked('reward_distributor'));
    bytes32 constant ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));
    bytes32 constant TREASURY_EXTENDER_HASH = keccak256(abi.encodePacked('treasury_extender'));
    bytes32 constant COMMUNITY_MANAGER_PAYOUT_CONTROLLER_HASH = keccak256(abi.encodePacked('community_manager_payout_controller'));

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
        BuyBackMFI,
        StartLiquidation,

        //Treasury extender
        AddAllocator,
        RequestReturnFromAllocator,
        GetTokensFromAllocator,
        SetAllocatorApprovalAmount,
        SetAllocatorStatus,
        SetAllocatorAllowanceIncreaseOnReturnPercentage,

        PayoutCommunityManagers,

        ChangeTimeLockTime
    }

    struct Action {
        ActionTypes actionType;
        string requestId;
        bytes data;
        uint256 executionAvailableTime;
        bool executed;
        address creator;
    }

    struct MultiSigAccount {
        address accountAddress;
        address votingAddress;
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
        ITokenCollector.CollectionType newCollectionType;
    }

    struct SetPriceCalculationTypeRequest {
        ITokenCollector.PriceCalculationType newPriceCalculationType;
    }

    struct SetAdditionalTokensPercentageRequest {
        uint256 newAdditionalTokensPercentage;
    }

    struct SetBonusTokenPercentageFromSwapRequest {
        uint256 newBonusTokenPercentageFromSwap;
    }

    struct StartTrackingTokenRequest {
        Treasury.TokenType tokenType;
        address token;
        bool isReserveToken;
        string liquidityControllerName;
    }

    struct StopTrackingTokenRequest {
        Treasury.TokenType tokenType;
        address token;
        string liquidityControllerName;
    }

    struct ProvideLiquidityRequest {
        string controllerName;
        address tokenToUse;
        uint256 amount;
        uint256 MFIMin;
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

    struct BuyBackMFIRequest {
        string buybackControllerName;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 minMFIOut;
    }

    struct StartLiquidationRequest {
        address payable claimEthTo;
        uint256 matrixLevels;
        string[] liquidityControllers;
        string[] buybackControllers;
        address[] priceCalcTokens;
    }

    struct AddAllocatorRequest {
        address allocator;
        address approvedToken;
        uint256 approvalAmount;
        uint256 allowanceIncreaseOnReturnPercentage;
    }

    struct RequestReturnFromAllocatorRequest {
        uint256 allocatorId;
    }

    struct GetTokensFromAllocatorRequest {
        uint256 allocatorId;
        uint256 numberOfTokens;
    }

    struct SetAllocatorApprovalAmountRequest {
        uint256 allocatorId;
        uint256 approvalAmount;
    }

    struct SetAllocatorStatusRequest {
        uint256 allocatorId;
        bool enabled;
    }

    struct SetAllocatorAllowanceIncreaseOnReturnPercentageRequest {
        uint256 allocatorId;
        uint256 allowanceIncreaseOnReturnPercentage;
    }

    struct PayoutCommunityManagersRequest {
        CommunityManagerPayoutController.PayoutMember[] payoutData;
    }

    struct ChangeTimeLockTimeRequest {
        uint256 newTime;
    }

    mapping(string => bool) public addedRequests;
    mapping(string => uint256) public systemIdToInternalId;
    mapping(uint256 => Action) public allActions;

    Counters.Counter public nextQueuedActionID;
    uint256 public timeLockTime = 48 hours;

    MultiSigAccount[] private multiSigAccounts;
    uint256 public signaturesRequired;

    constructor(ContractRegistry _contractRegistry, MultiSigAccount[] memory _multiSigAccounts, uint256 _signaturesRequired) EIP712("MultiSigMetFiManagerV2", "1") {

        for (uint256 x = 0; x < _multiSigAccounts.length; x++) {
            multiSigAccounts.push(_multiSigAccounts[x]);
        }

        require(_signaturesRequired < _multiSigAccounts.length, "You can't require 100% or more signatures");

        signaturesRequired = _signaturesRequired;

        contractRegistry = _contractRegistry;

        nextQueuedActionID.increment();
    }

    function replaceOwnWallet(address newWallet, uint256 deadline, bytes memory signature) public {

        require(block.timestamp < deadline, "Deadline exceeded");

        address signer = ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(keccak256("ReplaceOwnWallet(address newWallet,uint256 deadline)"), newWallet, deadline))), signature);

        for (uint256 x = 0; x < multiSigAccounts.length; x++) {
            if (multiSigAccounts[x].accountAddress == signer) {
                multiSigAccounts[x].accountAddress = newWallet;
                return;
            }
        }

        revert("no such member");
    }

    function setVotingAddress(address newAddress, uint256 deadline, bytes memory signature) public {

        require(block.timestamp < deadline, "Deadline exceeded");

        address signer = ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(keccak256("SetVotingAddress(address newAddress,uint256 deadline)"), newAddress, deadline))), signature);

        for (uint256 x = 0; x < multiSigAccounts.length; x++) {
            if (multiSigAccounts[x].accountAddress == signer) {
                multiSigAccounts[x].votingAddress = newAddress;
                return;
            }
        }

        revert("no such member");
    }

    function queueAction(Action memory action, bytes[] memory signatures, uint256 deadline) public {

        require(!addedRequests[action.requestId], "Request already added");
        addedRequests[action.requestId] = true;

        uint256 actionId = nextQueuedActionID.current();
        nextQueuedActionID.increment();

        require(signatures.length >= signaturesRequired, "Not enough signatures");
        require(block.timestamp < deadline, "Deadline exceeded");
        verifySignatures(action.actionType, deadline, action.data, signatures, action.requestId);

        action.executionAvailableTime = block.timestamp + timeLockTime;
        action.executed = false;
        action.creator = msg.sender;

        allActions[actionId] = action;
        systemIdToInternalId[action.requestId] = actionId;

        emit ActionQueued(uint256(action.actionType), actionId, action.requestId, action.data, action.executionAvailableTime);
    }

    function executeAction(uint256 actionId) public {

        Action memory action = allActions[actionId];

        require(!action.executed && action.executionAvailableTime <= block.timestamp && action.creator == msg.sender);
        allActions[actionId].executed = true;

        ActionTypes actionType = action.actionType;
        bytes memory data = action.data;

        if (actionType == ActionTypes.SetRequiredSignatures) {
            setRequiredSignatures(abi.decode(data, (SetRequiredSignaturesRequest)));
        } else if (actionType == ActionTypes.ReplaceMemberWallet) {
            replaceAccountWallet(abi.decode(data, (ReplaceAccountWalletRequest)));
        } else if (actionType == ActionTypes.ChangeLiquidationPeriods) {
            setLiquidationPeriods(abi.decode(data, (ChangeLiquidationPeriodsReq)));
        } else if (actionType == ActionTypes.SetContractAddress) {
            setContractAddress(abi.decode(data, (SetContractAddressRequest)));
        } else if (actionType == ActionTypes.SetMatrixAddress) {
            setMatrixAddress(abi.decode(data, (SetMatrixAddressRequest)));
        } else if (actionType == ActionTypes.AddMatrixLevel) {
            addMatrixLevel(abi.decode(data, (AddMatrixLevelRequest)));
        } else if (actionType == ActionTypes.SetLiquidityControllerAddress) {
            setLiquidityControllerAddress(abi.decode(data, (SetLiquidityControllerAddressRequest)));
        } else if (actionType == ActionTypes.SetBuybackControllerAddress) {
            setBuybackControllerAddress(abi.decode(data, (SetBuybackControllerAddressRequest)));
        } else if (actionType == ActionTypes.SetPriceCalcAddress) {
            setPriceCalcAddress(abi.decode(data, (SetPriceCalcAddressRequest)));
        } else if (actionType == ActionTypes.SetRealmGuardian) {
            setRealmGuardian(abi.decode(data, (SetRealmGuardianRequest)));
        } else if (actionType == ActionTypes.SetCoinMaster) {
            setCoinMaster(abi.decode(data, (SetCoinMasterRequest)));
        } else if (actionType == ActionTypes.SetBonusActivationTimeout) {
            setBonusActivationTimeout(abi.decode(data, (SetBonusActivationTimeoutRequest)));
        } else if (actionType == ActionTypes.SetCollectionType) {
            setCollectionType(abi.decode(data, (SetCollectionTypeRequest)));
        } else if (actionType == ActionTypes.SetPriceCalculationType) {
            setPriceCalculationType(abi.decode(data, (SetPriceCalculationTypeRequest)));
        } else if (actionType == ActionTypes.SetAdditionalTokensPercentage) {
            setAdditionalTokensPercentage(abi.decode(data, (SetAdditionalTokensPercentageRequest)));
        } else if (actionType == ActionTypes.SetBonusTokenPercentageFromSwap) {
            setBonusTokenPercentageFromSwap(abi.decode(data, (SetBonusTokenPercentageFromSwapRequest)));
        } else if (actionType == ActionTypes.StartTrackingToken) {
            startTrackingToken(abi.decode(data, (StartTrackingTokenRequest)));
        } else if (actionType == ActionTypes.StopTrackingToken) {
            stopTrackingToken(abi.decode(data, (StopTrackingTokenRequest)));
        } else if (actionType == ActionTypes.ProvideLiquidity) {
            provideLiquidity(abi.decode(data, (ProvideLiquidityRequest)));
        } else if (actionType == ActionTypes.RemoveLiquidity) {
            removeLiquidity(abi.decode(data, (RemoveLiquidityRequest)));
        } else if (actionType == ActionTypes.CollectLostTokensFromContract) {
            collectLostTokensFromContract(abi.decode(data, (CollectLostTokensFromContractRequest)));
        } else if (actionType == ActionTypes.Manage) {
            manage(abi.decode(data, (ManageRequest)));
        } else if (actionType == ActionTypes.BuyBackMFI) {
            buyBackMFI(abi.decode(data, (BuyBackMFIRequest)));
        } else if (actionType == ActionTypes.StartLiquidation) {
            startLiquidation(abi.decode(data, (StartLiquidationRequest)));
        } else if (actionType == ActionTypes.AddAllocator) {
            addAllocator(abi.decode(data, (AddAllocatorRequest)));
        } else if (actionType == ActionTypes.RequestReturnFromAllocator) {
            requestReturnFromAllocator(abi.decode(data, (RequestReturnFromAllocatorRequest)));
        } else if (actionType == ActionTypes.GetTokensFromAllocator) {
            getTokensFromAllocator(abi.decode(data, (GetTokensFromAllocatorRequest)));
        } else if (actionType == ActionTypes.SetAllocatorApprovalAmount) {
            setAllocatorApprovalAmount(abi.decode(data, (SetAllocatorApprovalAmountRequest)));
        } else if (actionType == ActionTypes.SetAllocatorStatus) {
            setAllocatorStatus(abi.decode(data, (SetAllocatorStatusRequest)));
        } else if (actionType == ActionTypes.SetAllocatorAllowanceIncreaseOnReturnPercentage) {
            setAllocatorAllowanceIncreaseOnReturnPercentage(abi.decode(data, (SetAllocatorAllowanceIncreaseOnReturnPercentageRequest)));
        } else if (actionType == ActionTypes.PayoutCommunityManagers) {
            payoutCommunityManagers(abi.decode(data, (PayoutCommunityManagersRequest)));
        } else if (actionType == ActionTypes.ChangeTimeLockTime) {
            changeTimeLockTime(abi.decode(data, (ChangeTimeLockTimeRequest)));
        }

        emit ActionExecuted(uint256(action.actionType), actionId, action.requestId, data);
    }

    function verifySignatures(ActionTypes actionType, uint256 deadline, bytes memory data, bytes[] memory signatures, string memory requestId) public view {

        address[] memory signers = new address[](signatures.length);
        for (uint256 x = 0; x < signatures.length; x++) {

            address current = ECDSA.recover(getActionHash(actionType, deadline, data, requestId), signatures[x]);

            bool approved = false;
            for (uint256 memberIndex = 0; memberIndex < multiSigAccounts.length; memberIndex++) {
                if (multiSigAccounts[memberIndex].votingAddress == current) {
                    approved = true;
                    break;
                }
            }

            require(approved, "Signer not approved");

            for (uint256 s = 0; s < signers.length; s++) {
                require(signers[s] != current, "Same address can only be used once");
            }

            signers[x] = current;

        }

    }

    function getActionHash(ActionTypes actionType, uint256 deadline, bytes memory data, string memory requestId) internal view returns (bytes32) {

        return _hashTypedDataV4(keccak256(abi.encode(
                keccak256("ManagerRequest(uint256 action_type,uint256 deadline,string requestId,bytes data)"),
                uint256(actionType),
                deadline,
                keccak256(bytes(requestId)),
                keccak256(data)
            )));
    }

    function setRequiredSignatures(SetRequiredSignaturesRequest memory request) internal {

        require(request.newRequiredSignatures < multiSigAccounts.length, "You can't require 100% or more signatures");

        signaturesRequired = request.newRequiredSignatures;
    }

    function replaceAccountWallet(ReplaceAccountWalletRequest memory request) internal {

        for (uint256 x = 0; x < multiSigAccounts.length; x++) {
            require(multiSigAccounts[x].accountAddress != request.newAddress, "Address already used");
        }

        for (uint256 x = 0; x < multiSigAccounts.length; x++) {
            if (multiSigAccounts[x].accountAddress == request.oldAddress) {
                multiSigAccounts[x].accountAddress = request.newAddress;
            }
        }
    }

    function setLiquidationPeriods(ChangeLiquidationPeriodsReq memory request) internal {
        AccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).setLiquidationPeriods(request.newLiquidationGracePeriod, request.newLiquidationClaimPeriod);
    }

    function setContractAddress(SetContractAddressRequest memory request) internal {
        contractRegistry.setContractAddress(request.name, request.newAddress);
    }

    function setMatrixAddress(SetMatrixAddressRequest memory request) internal {
        contractRegistry.setMatrixAddress(request.level, request.newAddress);
    }

    function addMatrixLevel(AddMatrixLevelRequest memory request) internal {
        contractRegistry.addMatrixLevel(request.newAddress);
    }

    function setLiquidityControllerAddress(SetLiquidityControllerAddressRequest memory request) internal {
        contractRegistry.setLiquidityControllerAddress(request.name, ILiquidityController(request.newAddress));
    }

    function setBuybackControllerAddress(SetBuybackControllerAddressRequest memory request) internal {
        contractRegistry.setBuybackControllerAddress(request.name, IBuybackController(request.newAddress));
    }

    function setPriceCalcAddress(SetPriceCalcAddressRequest memory request) internal {
        contractRegistry.setPriceCalcAddress(request.currencyAddress, request.calculatorAddress);
    }

    function setRealmGuardian(SetRealmGuardianRequest memory request) internal {
        contractRegistry.setRealmGuardian(request.guardianAddress, request.approved);
    }

    function setCoinMaster(SetCoinMasterRequest memory request) internal {
        contractRegistry.setCoinMaster(request.masterAddress, request.approved);
    }

    function setBonusActivationTimeout(SetBonusActivationTimeoutRequest memory request) internal {
        RewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH)).setBonusActivationTimeout(request.newBonusActivationTimeout);
    }

    function setCollectionType(SetCollectionTypeRequest memory request) internal {
        TokenCollector(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)).setCollectionType(request.newCollectionType);
    }

    function setPriceCalculationType(SetPriceCalculationTypeRequest memory request) internal {
        TokenCollector(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)).setPriceCalculationType(request.newPriceCalculationType);
    }

    function setAdditionalTokensPercentage(SetAdditionalTokensPercentageRequest memory request) internal {
        TokenCollector(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)).setAdditionalTokensPercentage(request.newAdditionalTokensPercentage);
    }

    function setBonusTokenPercentageFromSwap(SetBonusTokenPercentageFromSwapRequest memory request) internal {
        TokenCollector(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)).setBonusTokenPercentageFromSwap(request.newBonusTokenPercentageFromSwap);
    }

    function startTrackingToken(StartTrackingTokenRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).startTrackingToken(request.tokenType, request.token, request.isReserveToken, request.liquidityControllerName);
    }

    function stopTrackingToken(StopTrackingTokenRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).stopTrackingToken(request.tokenType, request.token, request.liquidityControllerName);
    }

    function provideLiquidity(ProvideLiquidityRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).provideLiquidity(request.controllerName, request.tokenToUse, request.amount, request.MFIMin);
    }

    function removeLiquidity(RemoveLiquidityRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).removeLiquidity(request.controllerName, request.tokenToUse, request.lpTokenAmount, request.tokenMin);
    }

    function collectLostTokensFromContract(CollectLostTokensFromContractRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).collectLostTokensFromContract(request.token, request.metFiContract);
    }

    function manage(ManageRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).manage(request.to, request.token, request.amount);
    }

    function buyBackMFI(BuyBackMFIRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).buyBackMFI(request.buybackControllerName, request.tokenAddress, request.tokenAmount, request.minMFIOut);
    }

    function startLiquidation(StartLiquidationRequest memory request) internal {
        Treasury(contractRegistry.getContractAddress(TREASURY_HASH)).startSystemLiquidation(request.claimEthTo, request.matrixLevels, request.liquidityControllers, request.buybackControllers, request.priceCalcTokens);
    }

    function addAllocator(AddAllocatorRequest memory request) internal {
        TreasuryExtender(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).addAllocator(request.allocator, request.approvedToken, request.approvalAmount, request.allowanceIncreaseOnReturnPercentage);
    }

    function requestReturnFromAllocator(RequestReturnFromAllocatorRequest memory request) internal {
        TreasuryExtender(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).requestReturnFromAllocator(request.allocatorId);
    }

    function getTokensFromAllocator(GetTokensFromAllocatorRequest memory request) internal {
        TreasuryExtender(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).getTokensFromAllocator(request.allocatorId, request.numberOfTokens);
    }

    function setAllocatorApprovalAmount(SetAllocatorApprovalAmountRequest memory request) internal {
        TreasuryExtender(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).setAllocatorApprovalAmount(request.allocatorId, request.approvalAmount);
    }

    function setAllocatorStatus(SetAllocatorStatusRequest memory request) internal {
        TreasuryExtender(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).setAllocatorStatus(request.allocatorId, request.enabled);
    }

    function setAllocatorAllowanceIncreaseOnReturnPercentage(SetAllocatorAllowanceIncreaseOnReturnPercentageRequest memory request) internal {
        TreasuryExtender(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).setAllocatorAllowanceIncreaseOnReturnPercentage(request.allocatorId, request.allowanceIncreaseOnReturnPercentage);
    }

    function payoutCommunityManagers(PayoutCommunityManagersRequest memory request) internal {
        CommunityManagerPayoutController(contractRegistry.getContractAddress(COMMUNITY_MANAGER_PAYOUT_CONTROLLER_HASH)).doThePayout(request.payoutData);
    }

    function changeTimeLockTime(ChangeTimeLockTimeRequest memory request) internal {
        timeLockTime = request.newTime;
    }
}