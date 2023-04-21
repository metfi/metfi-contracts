// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IPriceCalculator {

    function exchangePairSet() external view returns (bool);
    function getReserves() external view returns (uint256 calculatedTokenReserve, uint256 reserveTokenReserve);
    function getPriceInUSD() external view returns (uint256);
    function tokensForPrice(uint256 reserveTokenAmount) external view returns (uint256);
    function priceForTokens(uint256 numberOfTokens) external view returns (uint256);

}