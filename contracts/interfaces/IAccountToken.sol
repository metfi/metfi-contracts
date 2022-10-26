// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAccountToken {

    enum LiquidationStatus {
        NOT_REQUESTED,
        IN_PROGRESS,
        AVAILABLE
    }

    struct LiquidationInfo {
        LiquidationStatus status;
        uint256 requestTime;
        uint256 availableTime;
        uint256 expirationTime;
    }

    event AccountCreated(address indexed to, uint256 indexed tokenId, uint256 indexed directUplink, uint256 apy, string referralLink);
    event ReferralLinkChanged(uint256 indexed tokenId, string oldLink, string newLink);
    event AccountLiquidated(uint256 indexed nftId);
    event AccountLiquidationStarted(uint256 indexed nftId);
    event AccountLiquidationCanceled(uint256 indexed nftId);
    event AccountUpgraded(uint256 indexed nftId, uint256 indexed level, uint256 apy);

    function createAccount(address to, uint256 directUplink, uint256 level, string calldata newReferralLink) external returns (uint256);

    function setReferralLink(uint256 tokenId, string calldata referralLink) external;

    function accountLiquidated(uint256 tokenId) external view returns (bool);

    function getAddressNFTs(address userAddress) external view returns (uint256[] memory NFTs, uint256 numberOfActive);

    function balanceOf(address owner) external view returns (uint256 balance);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function upgradeAccountToLevel(uint256 tokenId, uint256 level) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function getAccountLevel(uint256 tokenId) external view returns (uint256);

    function getAccountDirectlyEnrolledMembers(uint256 tokenId) external view returns (uint256);

    function getAccountReferralLink(uint256 tokenId) external view returns (string memory);

    function getAccountByReferral(string calldata referralLink) external view returns (uint256);

    function referralLinkExists(string calldata referralCode) external view returns (bool);

    function getLevelMatrixParent(uint256, uint256) external view returns (uint256 newParent, uint256[] memory overtakenUsers);

    function getDirectUplink(uint256) external view returns (uint256);

    function getAverageAPY() external view returns (uint256);

    function totalMembers() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getLiquidationInfo(uint256 tokenId) external view returns (LiquidationInfo memory);

    function requestLiquidation(uint256 tokenId) external returns (bool);

    function liquidateAccount(uint256 tokenId) external;

    function cancelLiquidation(uint256 tokenId) external;

}