// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILiquidityController {

    event LiquidityProvided(address indexed tokenUsed, uint256 mfiProvided, uint256 liquidityTokensProvided, uint256 lpTokensReceived);
    event LiquidityRemoved(address indexed tokenUsed, uint256 lpTokensRedeemed, uint256 mfiReceived, uint256 liquidityTokensReceived);

    function getLPTokenAddress(address tokenToUse) external view returns (address);
    function claimableTokensFromTreasuryLPTokens(address tokenToUse) external view returns (uint256);
    function mfiRequiredForProvidingLiquidity(address tokenToUse, uint256 amount, uint256 MFIMin) external view returns (uint256);
    function provideLiquidity(address tokenToUse, uint256 amount, uint256 MFIMin) external;
    function removeLiquidity(address tokenToUse, uint256 lpTokenAmount, uint256 tokenMin) external;

}