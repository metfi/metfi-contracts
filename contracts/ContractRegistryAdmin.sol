// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./ContractRegistry.sol";

import "./TreasuryV2.sol";
import "./AccountToken.sol";
import "./TokenCollectorV2.sol";
import "./interfaces/IMETFI.sol";
import "./RewardDistributor.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IRouterV3.sol";
import "./interfaces/IUserConfig.sol";
import "./interfaces/IMETFIVault.sol";
import "./ContractRegistryHashes.sol";
import "./interfaces/ILendingView.sol";
import "./interfaces/ILoanLimiter.sol";
import "./interfaces/IPlatformViewV2.sol";
import "./interfaces/ILendingAuction.sol";
import "./interfaces/ILendingChecker.sol";
import "./interfaces/IPriceCalculator.sol";
import "./interfaces/IRewardConverter.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IStakingManagerV3.sol";
import "./interfaces/IMETFIStakingPool.sol";
import "./interfaces/IBurnControllerV2.sol";
import "./interfaces/ILendingCalculator.sol";
import "./interfaces/ILendingLoanExtensionController.sol";
import "./lending/Lending.sol";
import "./METFIStakingPool.sol";
import "./lending/LendingAuction.sol";
import "./NFTTransferProxyV2.sol";


contract ContractRegistryAdmin is ContractRegistryHashes {


    ContractRegistry internal contractRegistry;

    constructor(ContractRegistry _contractRegistry) {
        if (address(_contractRegistry) == address(0)) {
            revert InvalidContractAddress();
        }
        contractRegistry = _contractRegistry;
    }

    //-------------------------------------------------------------------------

    function onlyRouter() internal view {
        if (msg.sender != contractRegistry.getContractAddress(ROUTER_HASH)) {
            revert OnlyRouter();
        }
    }

    function onlyTreasury() internal view {
        if (msg.sender != contractRegistry.getContractAddress(TREASURY_HASH)) {
            revert OnlyTreasury();
        }
    }

    function onlyRealmGuardian() internal view {
        if (!contractRegistry.isRealmGuardian(msg.sender)) {
            revert OnlyRealmGuardian();
        }
    }

    function onlyStakingManager() internal view {
        if (msg.sender != contractRegistry.getContractAddress(STAKING_MANAGER_HASH)) {
            revert OnlyStakingManager();
        }
    }

    function onlyStakingManagerOrTokenCollector() internal view {
        if (msg.sender != contractRegistry.getContractAddress(STAKING_MANAGER_HASH) && msg.sender != contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)) {
            revert OnlyStakingManagerOrTokenCollector();
        }
    }

    function onlyRewardDistributor() internal view {
        if (msg.sender != contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH)) {
            revert OnlyRewardDistributor();
        }
    }

    function onlyCoinMaster() internal view {
        if (!contractRegistry.isCoinMaster(msg.sender)) {
            revert OnlyCoinMaster();
        }
    }

    function onlyTokenCollector() internal view {
        if (msg.sender != contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)) {
            revert OnlyTokenCollector();
        }
    }

    //-------------------------------------------------------------------------

    function getMFI() internal view returns (IERC20) {
        return IERC20(contractRegistry.getContractAddress(MFI_HASH));
    }

    function getMETFI() internal view returns (IMETFI) {
        return IMETFI(contractRegistry.getContractAddress(METFI_HASH));
    }

    function getRouter() internal view returns (IRouterV3) {
        return IRouterV3(contractRegistry.getContractAddress(ROUTER_HASH));
    }

    function getLending() internal view returns (Lending) {
        return Lending(contractRegistry.getContractAddress(LENDING_HASH));
    }

    function getTreasury() internal view returns (TreasuryV2) {
        return TreasuryV2(contractRegistry.getContractAddress(TREASURY_HASH));
    }

    function getMETFIVault() internal view returns (IMETFIVault) {
        return IMETFIVault(contractRegistry.getContractAddress(METFI_VAULT_HASH));
    }

    function getUserConfig() internal view returns (IUserConfig) {
        return IUserConfig(contractRegistry.getContractAddress(USER_CONFIG_HASH));
    }

    function getLendingView() internal view returns (ILendingView) {
        return ILendingView(contractRegistry.getContractAddress(LENDING_VIEW_HASH));
    }

    function getLoanLimiter() internal view returns (ILoanLimiter) {
        return ILoanLimiter(contractRegistry.getContractAddress(LOAN_LIMITER_HASH));
    }

    function getAccountToken() internal view returns (AccountToken) {
        return AccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
    }

    function getBurnController() internal view returns (IBurnControllerV2) {
        return IBurnControllerV2(contractRegistry.getContractAddress(BURN_CONTROLLER_HASH));
    }

    function getStakingManager() internal view returns (IStakingManagerV3) {
        return IStakingManagerV3(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
    }

    function getTokenCollector() internal view returns (TokenCollectorV2) {
        return TokenCollectorV2(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH));
    }

    function getLendingAuction() internal view returns (LendingAuction) {
        return LendingAuction(contractRegistry.getContractAddress(LENDING_AUCTION_HASH));
    }

    function getLendingChecker() internal view returns (ILendingChecker) {
        return ILendingChecker(contractRegistry.getContractAddress(LENDING_CHECKER_HASH));
    }


    function getMETFIStakingPool() internal view returns (METFIStakingPool) {
        return METFIStakingPool(contractRegistry.getContractAddress(METFI_STAKING_POOL_HASH));
    }


    function getRewardDistributor() internal view returns (RewardDistributor) {
        return RewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
    }

    function getLendingCalculator() internal view returns (ILendingCalculator) {
        return ILendingCalculator(contractRegistry.getContractAddress(LENDING_CALCULATOR_HASH));
    }

    function getLendingExtensionController() internal view returns (ILendingLoanExtensionController) {
        return ILendingLoanExtensionController(contractRegistry.getContractAddress(LENDING_EXTENSION_CONTROLLER_HASH));
    }

    function getPlatformView() internal view returns (IPlatformViewV2) {
        return IPlatformViewV2(contractRegistry.getContractAddress(PLATFORM_VIEW_HASH));
    }

    function getPriceCalculator(address token) internal view returns (IPriceCalculator) {
        return IPriceCalculator(contractRegistry.getPriceCalculator(token));
    }

    function getRewardConverter() internal view returns (IRewardConverter) {
        return IRewardConverter(contractRegistry.getContractAddress(REWARD_CONVERTER_HASH));
    }

    function getPancakeRouter() internal view returns (IPancakeRouter02) {
        return IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
    }

    function getNFTTransferProxy() internal view returns (NFTTransferProxyV2) {
        return NFTTransferProxyV2(contractRegistry.getContractAddress(NFT_TRANSFER_PROXY_HASH));
    }


}