// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract NFTTransferProxyV2 is ContractRegistryUser {

    event NFTTransferred(uint256 indexed nftId, address indexed to, address paymentCurrency);

    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public transferFeeInUSD;

    constructor(IContractRegistry _contractRegistry, uint256 _transferFeeInUSD) ContractRegistryUser(_contractRegistry) {
        require(_transferFeeInUSD <= 10, "Fee limit exceeded");
        transferFeeInUSD = _transferFeeInUSD;
    }

    function transferWithFee(uint256 id, address destination, IERC20 paymentCurrency, uint256 maxAmountIn) external payable {

        address paymentCurrencyAddress = address(paymentCurrency);

        uint256 transferFeeInPrimaryStableCoin = transferFeeInUSD * (10 ** getPrimaryStableCoinMetadata().decimals());
        if (msg.value > 0) {

            IPancakeRouter02 pancakeRouter = getPancakeRouter();

            paymentCurrencyAddress = address(pancakeRouter.WETH());

            address[] memory path = new address[](2);
            path[0] = pancakeRouter.WETH();
            path[1] = contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH);

            uint256 requiredBNBAmount = pancakeRouter.getAmountsIn(transferFeeInPrimaryStableCoin, path)[0];
            require(msg.value >= requiredBNBAmount, "insufficient msg value");
            require(maxAmountIn >= requiredBNBAmount, "Slippage exceeded");

            uint256 leftOverBNB = msg.value - requiredBNBAmount;

            pancakeRouter.swapExactETHForTokens{value : requiredBNBAmount}(transferFeeInPrimaryStableCoin, path, contractRegistry.getContractAddress(TREASURY_HASH), block.timestamp);

            if (leftOverBNB > 0) {
                payable(msg.sender).sendValue(leftOverBNB);
            }


        } else if (paymentCurrency != getPrimaryStableCoin()) {

            IPancakeRouter02 pancakeRouter = getPancakeRouter();

            address[] memory path = new address[](2);
            path[0] = address(paymentCurrency);
            path[1] = contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH);

            uint256[] memory amounts = pancakeRouter.getAmountsIn(transferFeeInPrimaryStableCoin, path);

            require(maxAmountIn >= amounts[0], "Slippage exceeded");

            paymentCurrency.safeApprove(address(pancakeRouter), amounts[0]);
            paymentCurrency.safeTransferFrom(msg.sender, address(this), amounts[0]);
            pancakeRouter.swapExactTokensForTokens(amounts[0], amounts[1], path, contractRegistry.getContractAddress(TREASURY_HASH), block.timestamp);


        } else {
            paymentCurrency.safeTransferFrom(msg.sender, contractRegistry.getContractAddress(TREASURY_HASH), transferFeeInPrimaryStableCoin);
        }

        getAccountTokenIERC721().safeTransferFrom(msg.sender, destination, id);

        emit NFTTransferred(id, destination, paymentCurrencyAddress);
    }

    function setTransferFeeInUSD(uint256 _transferFeeInUSD) external {
        onlyRealmGuardian();
        require(_transferFeeInUSD <= 10, "Fee limit exceeded");
        transferFeeInUSD = _transferFeeInUSD;
    }

}