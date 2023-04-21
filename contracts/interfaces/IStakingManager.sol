// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IStakingManager {

    event StakingAccountCreated(uint256 indexed nftId, uint256 indexed level, uint256 numberOfTokens);
    event StakingAccountLiquidated(uint256 indexed nftId, uint256 unstakedTokens);
    event TokensAddedToStaking(uint256 indexed nftId, uint256 numberOfTokens);
    event StakingAccountUpgraded(uint256 indexed nftId, uint256 indexed level, uint256 numberOfTokens);
    event StakingLevelRebased(uint256 indexed level, uint256 lockedTokens);
    event StakingRebased(uint256 totalTokens);

    function getAccountTokens(uint256 tokenId) external view returns(uint256);
    function createStakingAccount(uint256 tokenId, uint256 tokenAmount, uint256 level) external;
    function liquidateAccount(uint256 tokenId, address owner) external;
    function addTokensToStaking(uint256 tokenId, uint256 numberOfTokens) external;
    function upgradeStakingAccountToLevel(uint256 tokenId, uint256 level) external;
    function timeToNextRebase() external view returns (uint256);
    function nextRebaseAt() external view returns (uint256);
    function rebase() external;

    function enterLiquidation() external returns (uint256 totalMFIStaked);

}