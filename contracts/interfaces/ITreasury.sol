// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ITreasuryAllocator.sol";

interface ITreasury {

    event StakingRewardsDistributed(uint256 indexed amount);
    event RewardsSent(uint256 nftId, uint256 amount);

    function distributeStakingRewards(uint256 amount) external;
    function sendReward(uint256 nftId, uint256 amount) external;

    function getValue() external view returns (uint256 totalValue, uint256 riskFreeValue);
    function getTotalRewardsPaid() external view returns (uint256);

    function getTokensForCollector(address token, uint256 amount, address to) external;
}