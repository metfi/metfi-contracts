// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ITreasuryAllocator.sol";

interface ITreasuryV2 {

    enum TokenType {
        RESERVE_TOKEN,
        LP_TOKEN,
        LIQUIDITY_TOKEN
    }

    event StakingRewardsDistributed(uint256 indexed amount);
    event RewardsSent(uint256 nftId, uint256 amount);

    function sendReward(uint256 nftId, uint256 amount) external;

    function getTotalRewardsPaid() external view returns (uint256);

    function getValue() external view returns (uint256 totalValue, uint256 riskFreeValue);

    function getTokensForCollector(address token, uint256 amount, address to) external;
}