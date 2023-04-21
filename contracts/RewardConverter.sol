// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract RewardConverter is IRewardConverter, ContractRegistryUser {

    using SafeERC20 for IERC20;

    constructor(IContractRegistry _contractRegistry) ContractRegistryUser(_contractRegistry) {}

    function sendReward(uint256 nftId, IERC20 primaryStableCoin, uint256 amount) external override {
        require(primaryStableCoin.allowance(msg.sender, address(this)) >= amount, "Not enough allowance");

        address usersRewardCurrency = address(uint160(getUserConfig().getUserConfigUintValue(nftId, "reward_currency")));
        if (usersRewardCurrency == address(0) || usersRewardCurrency == address(primaryStableCoin)) {
            primaryStableCoin.safeTransferFrom(msg.sender, getAccountToken().ownerOf(nftId), amount);
            return;
        } else {

            address[] memory path = new address[](2);
            path[0] = address(primaryStableCoin);
            path[1] = usersRewardCurrency;

            IPancakeRouter02 pancakeRouter = getPancakeRouter();

            uint256 amountOut;
            try pancakeRouter.getAmountsOut(amount, path) returns (uint256[] memory amountsOut) {
                amountOut = amountsOut[1];
            } catch {
                primaryStableCoin.safeTransferFrom(msg.sender, getAccountToken().ownerOf(nftId), amount);
                return;
            }

            primaryStableCoin.safeTransferFrom(msg.sender, address(this), amount);
            primaryStableCoin.safeApprove(address(pancakeRouter), amount);

            pancakeRouter.swapExactTokensForTokens(
                amount,
                amountOut,
                path,
                getAccountToken().ownerOf(nftId),
                block.timestamp);

            return;

        }

    }

}
