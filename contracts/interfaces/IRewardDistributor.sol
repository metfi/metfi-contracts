// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IMatrix.sol";

interface IRewardDistributor {

    event AccountCreated(uint256 indexed nftId, uint256 indexed parentId);
    event AccountUpgraded(uint256 indexed nftId, uint256 indexed level);
    event BonusActivated(uint256 indexed nftId);
    event AccountLiquidated(uint256 indexed nftId);

    event RewardSent(uint256 indexed nftId, uint256 indexed from, uint256 indexed rewardType, uint256 level, uint256 matrixLevel, uint256 amount);
    event MatchingBonusSent(uint256 indexed nftId, uint256 indexed from, uint256 amount);
    event FastStartBonusReceived(uint256 indexed nftId, uint256 indexed from, uint256 amount, bool autoClaimed);

    struct RewardAccountInfo {
        uint256 ID;
        uint256 directUplink;
        uint256 fastStartBonus;
        uint256 receivedMatchingBonus;
        uint256 receivedMatrixBonus;
        uint64 bonusDeadline;
        uint64 activeBonusUsers;
        bool bonusActive;
        bool accountLiquidated;
    }

    function getAccountInfo(uint256 nftId) external view returns (RewardAccountInfo memory);
    function createAccount(uint256 nftId, uint256 parentId) external;
    function accountUpgraded(uint256 nftId, uint256 level) external;
    function liquidateAccount(uint256 nftId) external;
    function distributeRewards(uint256 distributionValue, uint256 rewardType, uint256 nftId, uint256 level) external;
}