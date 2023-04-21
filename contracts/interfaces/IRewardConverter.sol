// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewardConverter {

    function sendReward(uint256 nftId, IERC20 primaryStableCoin, uint256 amount) external;

}
