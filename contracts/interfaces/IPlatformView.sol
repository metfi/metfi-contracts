// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ITokenCollector.sol";
import "./IMatrix.sol";
import "./IRewardDistributor.sol";
import "./IUserConfig.sol";

interface IPlatformView {

    struct NFTData {
        uint256 ID;
        uint256 level;
        string referralLink;
        uint256 directUplink;
        uint256 stakedTokens;
        IRewardDistributor.RewardAccountInfo rewardingInfo;
        uint256[][] usersInLevel;
        uint256[] totalUsersInMatrix;
        uint256 directlyEnrolledMembers;
        uint256 liquidationRequestTime;
        uint256 liquidationAvailableTime;
        uint256 liquidationExpiredTime;
        bool liquidated;
        bool stakingPaused;
        bool readOnly;
        IUserConfig.UserConfigValues userConfigValues;
    }

    struct TreeNodeData {
        NFTData nftData;
        IMatrix.Node node;
    }

    struct PlatformData {
        uint256 MFIPrice;
        uint256 totalMembers;
        uint256 averageAPY;
        uint256 treasuryValue;
        uint256 treasuryRiskFreeValue;
        uint256 stakedTokens;
        uint256 valuePerToken;
        uint256 backingPerToken;
        uint256 nextRebaseAt;
        uint256 totalRewardsPaid;
        ITokenCollector.CollectionType tokenCollectionType;
        ITokenCollector.PriceCalculationType priceCalculationType;
        uint256 tokenCollectionPercentage;
        uint256 mfiLiquidityReserve;
        uint256 stableCoinLiquidityReserve;
    }

    function getWalletData(address wallet) external view returns (NFTData[] memory);
    function getNFTData(uint256 nftId) external view returns (NFTData memory NFT);
    function getReferralCodeData(string calldata referralCode) external view returns (NFTData memory);
    function referralLinkExists(string calldata referralCode) external view returns (bool);

    function getAddressActiveLoanNFTs(address borrower) external view returns (uint256[] memory);

    function getMFIPrice() external view returns (uint256);
    function getPlatformData() external view returns (PlatformData memory);

    function getTreeData(uint256 nftId, uint256 matrixLevel, uint256 toDepthLevel) external view returns (TreeNodeData memory selectedNFT, TreeNodeData[] memory subNFTs);

    function stakedTokens(uint256 nftId) external view returns (uint256);
    function stakingPaused(uint256 nftId) external view returns (bool);
    function stakedTokensForAddress(address wallet) external view returns (uint256);
    function getUsersInLevels(uint256 nodeId, uint256 level) external view returns (uint256[] memory levels, uint256 totalUsers);

}