// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract TokenCollectorV2 is ITokenCollectorV2, ContractRegistryUser {

    using SafeERC20 for IERC20;
    using Address for address payable;

    CollectionType public collectionType;
    PriceCalculationType public priceCalculationType;

    bool usePool; // true - use pool, false - use vault
    bool fullFromSwap; // true - buy 85 % METFI from pancakeswap and collect 15% from  pool/vault, false - collect 100% from pool/vault

    uint256 additionalTokensPercentage = 10;
    uint256 bonusTokenPercentageFromSwap = 100;

    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry, bool _usePool, bool _fullFromSwap) ContractRegistryUser(_contractRegistry) {

        collectionType = CollectionType.SWAP;
        priceCalculationType = PriceCalculationType.TOKEN_PRICE_BASED;

        usePool = _usePool;
        fullFromSwap = _fullFromSwap;

    }

    function getBonusTokens(uint256 primaryStableCoinPrice, uint256 minBonusTokens) external override returns (uint256) {
        onlyRouter();
        IPriceCalculator priceCalc = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(METFI_HASH)));
        IERC20 metfi = getMETFIERC20();
        IERC20 primaryStableCoin = getPrimaryStableCoin();

        address to = contractRegistry.getContractAddress(STAKING_MANAGER_HASH);

        uint256 tokensForPrice = priceCalc.tokensForPrice(primaryStableCoinPrice);
        uint256 tokensFromSwap = (tokensForPrice * bonusTokenPercentageFromSwap) / 100;
        uint256 tokensToCollect = tokensForPrice - tokensFromSwap;

        if (tokensToCollect > 0) {
            collectMETFI(tokensToCollect, to);
        }

        if (tokensFromSwap > 0) {

            uint256 valueFromSwap = (primaryStableCoinPrice * bonusTokenPercentageFromSwap) / 100;

            getTreasury().getTokensForCollector(address(primaryStableCoin), valueFromSwap, address(this));
            IPancakeRouter02 pancakeRouter = getPancakeRouter();

            primaryStableCoin.approve(address(pancakeRouter), valueFromSwap);

            address[] memory path = new address[](2);
            (path[0], path[1]) = (address(primaryStableCoin), address(metfi));

            uint256[] memory amounts = pancakeRouter.swapExactTokensForTokens(
                valueFromSwap,
                tokensFromSwap,
                path,
                to,
                block.timestamp
            );

            tokensForPrice = tokensToCollect + amounts[amounts.length - 1];
        }

        require(tokensForPrice >= minBonusTokens, "Slippage exceeded");

        emit CollectedBonusTokens(primaryStableCoinPrice, tokensForPrice);

        return tokensForPrice;
    }

    function getTokens(uint256 primaryStableCoinPrice, uint256 minTokensOut) external override returns (uint256){
        onlyRouter();
        IPriceCalculator priceCalc = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(METFI_HASH)));
        IERC20 metfi = getMETFIERC20();
        IERC20 primaryStableCoin = getPrimaryStableCoin();

        address to = contractRegistry.getContractAddress(STAKING_MANAGER_HASH);

        if (collectionType == CollectionType.SWAP) {

            uint256 percentageFromSwap = (!fullFromSwap) ? 85 : 100;
            uint256 valueFromSwap = (primaryStableCoinPrice * percentageFromSwap) / 100;
            uint256 minTokensOutSwap = (minTokensOut * percentageFromSwap) / 100;

            getTreasury().getTokensForCollector(address(primaryStableCoin), valueFromSwap, address(this));

            IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));

            primaryStableCoin.approve(address(pancakeRouter), valueFromSwap);

            address[] memory path = new address[](2);
            (path[0], path[1]) = (address(primaryStableCoin), address(metfi));

            uint256[] memory amounts = pancakeRouter.swapExactTokensForTokens(
                valueFromSwap,
                minTokensOutSwap,
                path,
                to,
                block.timestamp
            );

            uint256 receivedTokens = amounts[amounts.length - 1];

            if (percentageFromSwap != 100) {

                uint256 tokensToCollectFromPool = (receivedTokens * (100 - percentageFromSwap)) / percentageFromSwap;
                collectMETFI(tokensToCollectFromPool, to);

                receivedTokens += tokensToCollectFromPool;
            }

            require(receivedTokens >= minTokensOut, "Slippage exceeded");

            emit CollectedTokens(primaryStableCoinPrice, receivedTokens, uint256(collectionType), uint256(priceCalculationType));

            return receivedTokens;
        } else if (collectionType == CollectionType.POOL) {

            uint256 tokensForPrice = priceCalc.tokensForPrice(primaryStableCoinPrice);

            if (priceCalculationType == PriceCalculationType.TOKEN_PRICE_BASED) {
                tokensForPrice = (primaryStableCoinPrice * (10 ** ERC20(address(primaryStableCoin)).decimals())) / priceCalc.getPriceInUSD();
            }

            tokensForPrice = tokensForPrice * (100 + additionalTokensPercentage) / 100;

            if (minTokensOut > 0) {
                require(tokensForPrice >= minTokensOut, "Slippage exceeded");
            }

            collectMETFI(tokensForPrice, to);

            emit CollectedTokens(primaryStableCoinPrice, tokensForPrice, uint256(collectionType), uint256(priceCalculationType));

            return tokensForPrice;

        } else {
            revert("Broken config");
        }
    }

    function getCollectionType() external view override returns (CollectionType) {
        return collectionType;
    }

    function getPriceCalculationType() external view override returns (PriceCalculationType) {
        return priceCalculationType;
    }

    function getAdditionalTokensPercentage() external view override returns (uint256) {
        return additionalTokensPercentage;
    }

    function setCollectionType(CollectionType newCollectionType) external {
        onlyRealmGuardian();

        if (newCollectionType == CollectionType.SWAP) {
            IPriceCalculator priceCalc = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(METFI_HASH)));
            require(priceCalc.exchangePairSet(), "Pair is not set in calculator");
            require(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH) != address(0), "Pancake router is not set");
        }

        collectionType = newCollectionType;

        emit CollectionTypeChanged(uint256(newCollectionType));
    }

    function setBoolValues(bool _fullFromSwap, bool _usePool) external {
        onlyRealmGuardian();

        fullFromSwap = _fullFromSwap;
        usePool = _usePool;

        emit BoolValuesChanged(_fullFromSwap, _usePool);
    }

    function setPriceCalculationType(PriceCalculationType newPriceCalculationType) external {
        onlyRealmGuardian();

        priceCalculationType = newPriceCalculationType;

        emit PriceCalculationTypeChanged(uint256(priceCalculationType));
    }

    function setAdditionalTokensPercentage(uint256 _additionalTokensPercentage) external {
        onlyRealmGuardian();

        additionalTokensPercentage = _additionalTokensPercentage;

        emit AdditionalTokensPercentageChanged(_additionalTokensPercentage);
    }

    function collectMETFI(uint256 amount, address to) internal {
        if (usePool) {
            getMETFIStakingPool().withdrawMETFI(to, amount);
        } else {
            getMETFIVault().withdrawMETFI(to, amount);
        }

    }

    function setBonusTokenPercentageFromSwap(uint256 _bonusTokenPercentageFromSwap) external {
        onlyRealmGuardian();

        require(_bonusTokenPercentageFromSwap <= 100, "wrong bonus token percentage");
        bonusTokenPercentageFromSwap = _bonusTokenPercentageFromSwap;

        emit BonusTokenPercentageFromSwapChanged(_bonusTokenPercentageFromSwap);
    }


}