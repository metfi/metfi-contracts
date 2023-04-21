// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRewardDistributor.sol";
import "./ITokenCollector.sol";
import "./IMatrix.sol";
import "./ILendingStructs.sol";

interface IRouterV3 {

    event AccountCreated(uint256 indexed nftId, uint256 indexed parentId, uint256 indexed level, uint256 additionalTokensPrice, string referralLink, uint256 freeMFITokensReceived);
    event AccountLiquidationStarted(uint256 indexed nftId);
    event AccountLiquidationCanceled(uint256 indexed nftId);
    event AccountLiquidated(uint256 indexed nftId);
    event AccountUpgraded(uint256 indexed nftId, uint256 indexed level, uint256 additionalTokensPrice, uint256 freeMFITokensReceived);
    event TokensStaked(uint256 indexed nftId, uint256 numberOfTokens);
    event TokensBought(uint256 indexed nftId, uint256 usdtPrice, uint256 numberOfTokens, uint256 accountLevel);
    event AccountOvertaken(uint256 indexed overtakenAccount, uint256 indexed overtakenBy, uint256 indexed level);
    event StakingResumed(uint256 indexed nftId);

    function resumeStaking(uint256 nftId) external;

    function createAccount(address newOwner, uint256 level, uint256 minTokensOut, uint256 minBonusTokens, string calldata newReferralLink, uint256 additionalTokensValue, bool isCrypto, address paymentCurrency,uint256 maxTokensIn) external payable returns (uint256);
    function createAccountWithReferral(address newOwner, string calldata referralId, uint256 level, uint256 minTokensOut, uint256 minBonusTokens, string calldata newReferralLink, uint256 additionalTokensValue, bool isCrypto, address paymentCurrency,uint256 maxTokensIn) external payable returns (uint256);
    function upgradeNFTToLevel(uint256 nftId, uint256 minTokensOut, uint256 minBonusTokens, uint256 finalLevel, uint256 additionalTokensValue, address paymentCurrency,uint256 maxTokensIn) external payable;


    function setReferralLink(uint256 nftId, string calldata newReferralLink) external;

    function liquidateAccount(uint256 nftId) external;
    function cancelLiquidation(uint256 nftId) external;

    function stakeTokens(uint256 nftId, uint256 numberOfTokens) external;

    function setUserConfigUintValue(uint256 nftId, string memory key, uint256 value) external;
    function setUserConfigStringValue(uint256 nftId, string memory key, string memory value) external;

    function buyTokens(uint256 nftId, uint256 primaryStableCoinPrice, uint256 minTokensOut, IERC20 paymentCurrency) payable external;

}