// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ITokenCollector.sol";

interface ITokenCollectorV2 {

    event CollectedBonusTokens(uint256 stableCoinPrice, uint256 numberOfTokens);
    event CollectedTokens(uint256 stableCoinPrice, uint256 numberOfTokens, uint256 collectionType, uint256 slippageCalculationType);
    event CollectionTypeChanged(uint256 collectionType);
    event PriceCalculationTypeChanged(uint256 priceCalculationType);
    event AdditionalTokensPercentageChanged(uint256 additionalTokensPercentage);
    event BonusTokenPercentageFromSwapChanged(uint256 bonusTokenPercentageFromSwap);
    event BoolValuesChanged(bool fullFromSwap, bool usePool);

    enum CollectionType {
        SWAP,
        POOL
    }

    enum PriceCalculationType {
        TOKEN_PRICE_BASED,
        POOL_BASED
    }

    function getBonusTokens(uint256 stableCoinPrice, uint256 minBonusTokens) external returns (uint256);
    function getTokens(uint256 stableCoinPrice, uint256 minTokensOut) external returns (uint256);
    function getCollectionType() external view returns (CollectionType);
    function getPriceCalculationType() external view returns (PriceCalculationType);
    function getAdditionalTokensPercentage() external view returns (uint256);

}