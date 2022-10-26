// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRewardDistributor.sol";
import "./ITokenCollector.sol";
import "./IMatrix.sol";

interface IRouter {

    event AccountCreated(uint256 indexed nftId, uint256 indexed parentId, uint256 indexed level, uint256 additionalTokensPrice, string referralLink, uint256 freeMFITokensReceived);
    event AccountLiquidationStarted(uint256 indexed nftId);
    event AccountLiquidationCanceled(uint256 indexed nftId);
    event AccountLiquidated(uint256 indexed nftId);
    event AccountUpgraded(uint256 indexed nftId, uint256 indexed level, uint256 additionalTokensPrice, uint256 freeMFITokensReceived);
    event TokensStaked(uint256 indexed nftId, uint256 numberOfTokens);
    event TokensBought(uint256 indexed nftId, uint256 busdPrice, uint256 numberOfTokens, uint256 accountLevel);
    event AccountOvertaken(uint256 indexed overtakenAccount, uint256 indexed overtakenBy, uint256 indexed level);

    function createAccount(address newOwner, uint256 level, uint256 minTokensOut, string calldata newReferralLink, uint256 additionalTokensValue) external returns (uint256 newTokenID);
    function createAccountWithReferral(address newOwner, string calldata referralId, uint256 level, uint256 minTokensOut, string calldata newReferralLink, uint256 additionalTokensValue) external returns (uint256 newTokenID);
    function upgradeNFTToLevel(uint256 nftId, uint256 minTokensOut, uint256 finalLevel, uint256 additionalTokensValue) external;

    function setReferralLink(uint256 nftId, string calldata newReferralLink) external;

    function liquidateAccount(uint256 nftId) external;
    function cancelLiquidation(uint256 nftId) external;

    function stakeTokens(uint256 nftId, uint256 numberOfTokens) external;
    function buyTokens(uint256 nftId, uint256 busdPrice, uint256 minTokensOut) external;

}