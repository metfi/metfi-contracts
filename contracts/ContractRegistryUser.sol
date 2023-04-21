// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./interfaces/IContractRegistry.sol";
import "./ContractRegistryHashes.sol";

import "./interfaces/IMETFI.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IRouterV3.sol";
import "./interfaces/ITreasuryV2.sol";
import "./interfaces/IUserConfig.sol";
import "./interfaces/IMETFIVault.sol";
import "./interfaces/ILendingView.sol";
import "./interfaces/ILoanLimiter.sol";
import "./interfaces/IAccountToken.sol";
import "./interfaces/IPlatformView.sol";
import "./interfaces/ISecurityProxy.sol";
import "./interfaces/ILendingAuction.sol";
import "./interfaces/ILendingChecker.sol";
import "./interfaces/IPlatformViewV2.sol";
import "./interfaces/IPriceCalculator.sol";
import "./interfaces/IRewardConverter.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IValueCalculator.sol";
import "./interfaces/IStakingManagerV3.sol";
import "./interfaces/ITokenCollectorV2.sol";
import "./interfaces/IMETFIStakingPool.sol";
import "./interfaces/IBurnControllerV2.sol";
import "./interfaces/ILendingCalculator.sol";
import "./interfaces/IManageableTreasury.sol";
import "./interfaces/IDestroyableContract.sol";
import "./interfaces/ILendingPlatformView.sol";
import "./interfaces/ILiquidityController.sol";
import "./interfaces/ILendingLoanExtensionController.sol";


abstract contract ContractRegistryUser is ContractRegistryHashes, ILostTokenProvider {

    using Address for address payable;
    using SafeERC20 for IERC20;

    IContractRegistry internal contractRegistry;

    constructor(IContractRegistry _contractRegistry) {
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

    function getLostTokens(address tokenAddress) public virtual override {
        onlyTreasury();

        IERC20 token = IERC20(tokenAddress);
        if (token.balanceOf(address(this)) > 0) {
            token.safeTransfer(msg.sender, token.balanceOf(address(this)));
        }
        if (address(this).balance > 0) {
            payable(msg.sender).sendValue(address(this).balance);
        }
    }

    //-------------------------------------------------------------------------

    function getMFI() internal view returns (IERC20) {
        return IERC20(contractRegistry.getContractAddress(MFI_HASH));
    }

    function getMETFI() internal view returns (IMETFI) {
        return IMETFI(contractRegistry.getContractAddress(METFI_HASH));
    }
    function getMETFIERC20() internal view returns (IERC20) {
        return IERC20(contractRegistry.getContractAddress(METFI_HASH));
    }

    function getRouter() internal view returns (IRouterV3) {
        return IRouterV3(contractRegistry.getContractAddress(ROUTER_HASH));
    }

    function getLending() internal view returns (ILending) {
        return ILending(contractRegistry.getContractAddress(LENDING_HASH));
    }

    function getTreasury() internal view returns (ITreasuryV2) {
        return ITreasuryV2(contractRegistry.getContractAddress(TREASURY_HASH));
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

    function getAccountToken() internal view returns (IAccountToken) {
        return IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
    }

    function getAccountTokenIERC721() internal view returns (IERC721) {
        return IERC721(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
    }

    function getBurnController() internal view returns (IBurnControllerV2) {
        return IBurnControllerV2(contractRegistry.getContractAddress(BURN_CONTROLLER_HASH));
    }

    function getStakingManager() internal view returns (IStakingManagerV3) {
        return IStakingManagerV3(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
    }

    function getTokenCollector() internal view returns (ITokenCollectorV2) {
        return ITokenCollectorV2(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH));
    }

    function getLendingAuction() internal view returns (ILendingAuction) {
        return ILendingAuction(contractRegistry.getContractAddress(LENDING_AUCTION_HASH));
    }

    function getLendingChecker() internal view returns (ILendingChecker) {
        return ILendingChecker(contractRegistry.getContractAddress(LENDING_CHECKER_HASH));
    }


    function getMETFIStakingPool() internal view returns (IMETFIStakingPool) {
        return IMETFIStakingPool(contractRegistry.getContractAddress(METFI_STAKING_POOL_HASH));
    }


    function getRewardDistributor() internal view returns (IRewardDistributor) {
        return IRewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
    }

    function getLendingCalculator() internal view returns (ILendingCalculator) {
        return ILendingCalculator(contractRegistry.getContractAddress(LENDING_CALCULATOR_HASH));
    }

    function getLendingExtensionController() internal view returns (ILendingLoanExtensionController) {
        return ILendingLoanExtensionController(contractRegistry.getContractAddress(LENDING_EXTENSION_CONTROLLER_HASH));
    }

    function getPlatformView() internal view returns (IPlatformView) {
        return IPlatformView(contractRegistry.getContractAddress(PLATFORM_VIEW_HASH));
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

    function getPrimaryStableCoin() internal view returns (IERC20) {
        return IERC20(contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH));
    }

    function getPrimaryStableCoinMetadata() internal view returns (IERC20Metadata) {
        return IERC20Metadata(contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH));
    }

    function getLendingPlatformView() internal view returns (ILendingPlatformView) {
        return ILendingPlatformView(contractRegistry.getContractAddress(LENDING_HASH));
    }

    function getPlatformViewV2() internal view returns (IPlatformViewV2) {
        return IPlatformViewV2(contractRegistry.getContractAddress(PLATFORM_VIEW_HASH));
    }


}