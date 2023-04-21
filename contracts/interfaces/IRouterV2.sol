// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRewardDistributor.sol";
import "./ITokenCollector.sol";
import "./IMatrix.sol";
import "./ILendingStructs.sol";
import "./IRouter.sol";

interface IRouterV2 is IRouter {

    event StakingResumed(uint256 indexed nftId);

    function resumeStaking(uint256 nftId) external;

}