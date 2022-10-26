// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITokenCollector {

    event CollectedBonusTokens(uint256 busdPrice, uint256 numberOfTokens);
    event CollectedTokens(uint256 busdPrice, uint256 numberOfTokens, uint256 collectionType, uint256 slippageCalculationType);
    event CollectionTypeChanged(uint256 collectionType);
    event PriceCalculationTypeChanged(uint256 priceCalculationType);

    enum CollectionType {
        MINTING,
        SWAP
    }

    enum PriceCalculationType {
        TOKEN_PRICE_BASED,
        POOL_BASED
    }

    function getBonusTokens(uint256 busdPrice) external returns (uint256);
    function getTokens(uint256 busdPrice, uint256 minTokensOut) external returns (uint256);
    function getCollectionType() external view returns (CollectionType);
    function getPriceCalculationType() external view returns (PriceCalculationType);
    function getAdditionalTokensPercentage() external view returns (uint256);
}