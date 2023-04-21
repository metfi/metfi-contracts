// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract RouterV3 is IRouterV3, IDestroyableContract, ContractRegistryUser {

    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256[] private levelPricesInPrimaryStableCoin;

    //----------------- Access control -------------------------------------------------------------------------------

    function verifySenderAndNFT(uint256 nftId) internal view {
        IAccountToken accountTokens = getAccountToken();
        require(accountTokens.ownerOf(nftId) == msg.sender, "You don't own this token");
        require(!accountTokens.accountLiquidated(nftId), "Account liquidated");
    }


    function onlyEOA() internal view {
        require(msg.sender == tx.origin, "not EOA");
    }
    //----------------------------------------------------------------------------------------------------------------

    constructor(
        IContractRegistry _contractRegistry,
        uint256[] memory _levelPricesInUSD
    ) ContractRegistryUser(_contractRegistry) {

        require(_levelPricesInUSD.length == 10, "wrong _levelPricesInUSD length");

        levelPricesInPrimaryStableCoin = new uint256[](10);

        for (uint256 x = 0; x < _levelPricesInUSD.length; x++) {
            levelPricesInPrimaryStableCoin[x] = _levelPricesInUSD[x];
        }
    }

    //Account management ----------------
    function createAccount(address newOwner, uint256 level, uint256 minTokensOut, uint256 minBonusTokens, string calldata newReferralLink, uint256 additionalTokensValue, bool isCrypto, address paymentCurrency, uint256 maxTokensIn) public payable override returns (uint256) {
        onlyEOA();

        return _createAccount(newOwner, 1, level, minTokensOut, minBonusTokens, newReferralLink, additionalTokensValue, isCrypto, paymentCurrency, maxTokensIn);
    }


    function createAccountWithReferral(address newOwner, string calldata referralId, uint256 level, uint256 minTokensOut, uint256 minBonusTokens, string calldata newReferralLink, uint256 additionalTokensValue, bool isCrypto, address paymentCurrency, uint256 maxTokensIn) public payable override returns (uint256) {
        onlyEOA();

        uint256 parentId = getAccountToken().getAccountByReferral(referralId);
        return _createAccount(newOwner, parentId, level, minTokensOut, minBonusTokens, newReferralLink, additionalTokensValue, isCrypto, paymentCurrency, maxTokensIn);
    }

    function _createAccount(address newOwner, uint256 parentId, uint256 level, uint256 minTokensOut, uint256 minBonusTokens, string calldata newReferralLink, uint256 additionalTokensValue, bool isCrypto, address paymentCurrency, uint256 maxTokensIn) internal returns (uint256) {

        rebaseStaking();

        require(level < levelPricesInPrimaryStableCoin.length, "Level does not exist");

        {// Wrap to avoid stack too deep error
            (, uint256 totalActiveNFTs) = getAccountToken().getAddressNFTs(newOwner);
            require(totalActiveNFTs == 0, "This user already owns position");
        }

        //Mint new token
        uint256 newTokenID = getAccountToken().createAccount(newOwner, parentId, level, newReferralLink);

        getRewardDistributor().createAccount(newTokenID, parentId);
        getUserConfig().setUserConfigUintValue(newTokenID, "is_crypto", isCrypto ? 1 : 0);


        uint256 freeMFITokensReceived = handleLevelCreationAndUpgrades(newTokenID, 0, level, additionalTokensValue, minTokensOut, minBonusTokens, maxTokensIn, paymentCurrency);

        emit AccountCreated(newTokenID, parentId, level, additionalTokensValue, newReferralLink, freeMFITokensReceived);

        return newTokenID;
    }

    function upgradeNFTToLevel(uint256 nftId, uint256 minTokensOut, uint256 minBonusTokens, uint256 finalLevel, uint256 additionalTokensValue, address paymentCurrency, uint256 maxTokensIn) external payable override {
        onlyEOA();
        verifySenderAndNFT(nftId);

        rebaseStaking();

        IAccountToken accountTokens = getAccountToken();

        require(finalLevel < levelPricesInPrimaryStableCoin.length, "Level does not exist");

        uint256 currentLevel = accountTokens.getAccountLevel(nftId);

        require(finalLevel > currentLevel, "Next level <= current level");

        accountTokens.upgradeAccountToLevel(nftId, finalLevel);

        uint256 freeMFITokensReceived = handleLevelCreationAndUpgrades(nftId, currentLevel + 1, finalLevel, additionalTokensValue, minTokensOut, minBonusTokens, maxTokensIn, paymentCurrency);

        emit AccountUpgraded(nftId, finalLevel, additionalTokensValue, freeMFITokensReceived);
    }

    function handleLevelCreationAndUpgrades(uint256 nftId, uint256 initialLevel, uint256 finalLevel, uint256 additionalTokensValue, uint256 minTokensOut, uint256 minBonusTokens, uint256 maxTokensIn, address paymentCurrency) internal returns (uint256 freeMFITokensReceived) {

        uint256 levelsPrice = 0;

        for (uint256 nextLevel = initialLevel; nextLevel <= finalLevel; nextLevel++) {
            levelsPrice += levelPricesInPrimaryStableCoin[nextLevel];
        }

        levelsPrice *= (10 ** getPrimaryStableCoinMetadata().decimals());

        if (msg.value > 0) {
            uint totalPriceWithConversionFee = ((levelsPrice + additionalTokensValue) * 1005) / 1000;

            IPancakeRouter02 pancakeRouter = getPancakeRouter();

            address[] memory path = new address[](2);
            path[0] = pancakeRouter.WETH();
            path[1] = contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH);

            uint256 requiredBNBAmount = pancakeRouter.getAmountsIn(totalPriceWithConversionFee, path)[0];
            require(msg.value >= requiredBNBAmount, "insufficient msg value");
            uint256 leftOverBNB = msg.value - requiredBNBAmount;

            pancakeRouter.swapExactETHForTokens{value : requiredBNBAmount}(totalPriceWithConversionFee, path, contractRegistry.getContractAddress(TREASURY_HASH), block.timestamp);

            if (leftOverBNB > 0) {
                payable(msg.sender).sendValue(leftOverBNB);
            }


        } else if (paymentCurrency != contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH)) {
            uint totalPriceWithConversionFee = ((levelsPrice + additionalTokensValue) * 1005) / 1000;

            address[] memory path = new address[](2);
            path[0] = paymentCurrency;
            path[1] = contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH);

            IPancakeRouter02 pancakeRouter = getPancakeRouter();
            uint256[] memory amounts = pancakeRouter.getAmountsIn(totalPriceWithConversionFee, path);

            require(amounts[0] <= maxTokensIn, "Max tokens in exceeded");

            IERC20(paymentCurrency).safeTransferFrom(msg.sender, address(this), amounts[0]);
            IERC20(paymentCurrency).safeApprove(address(pancakeRouter), amounts[0]);
            pancakeRouter.swapExactTokensForTokens(amounts[0], totalPriceWithConversionFee, path, contractRegistry.getContractAddress(TREASURY_HASH), block.timestamp);

        } else {
            getPrimaryStableCoin().safeTransferFrom(msg.sender, contractRegistry.getContractAddress(TREASURY_HASH), levelsPrice + additionalTokensValue);

        }

        {// Wrapped to avoid stack too deep error
            for (uint256 nextLevel = initialLevel; nextLevel <= finalLevel; nextLevel++) {

                {
                    (uint256 nextMatrixParentId, uint256[] memory accountsOvertaken) = getAccountToken().getLevelMatrixParent(nftId, nextLevel);
                    contractRegistry.getMatrix(nextLevel).addNode(nftId, nextMatrixParentId);

                    for (uint256 x = 0; x < accountsOvertaken.length; x++) {
                        emit AccountOvertaken(accountsOvertaken[x], nftId, nextLevel);
                    }
                }
                IRewardDistributor rewardDistributor = getRewardDistributor();
                rewardDistributor.accountUpgraded(nftId, nextLevel);
                rewardDistributor.distributeRewards(levelPricesInPrimaryStableCoin[nextLevel] * (10 ** getPrimaryStableCoinMetadata().decimals()), 0, nftId, nextLevel);
            }
        }


        //Add required number of tokens directly into the staking manager
        uint256 totalTokens = getTokenCollector().getBonusTokens(levelsPrice / 10, minBonusTokens);
        freeMFITokensReceived = totalTokens;

        if (additionalTokensValue > 0) {

            //Emit TokensBought event when adding tokens at upgrade
            uint256 tokensBought = getTokenCollector().getTokens(additionalTokensValue, minTokensOut);
            totalTokens += tokensBought;

            getRewardDistributor().distributeRewards(additionalTokensValue, 1, nftId, finalLevel);
            emit TokensBought(nftId, additionalTokensValue, tokensBought, finalLevel);
        }

        {// Wrapped to avoid stack too deep error
            IStakingManagerV3 stakingManager = getStakingManager();
            if (initialLevel == 0) {
                stakingManager.createStakingAccount(nftId, totalTokens, finalLevel);
            } else {
                stakingManager.upgradeStakingAccountToLevel(nftId, finalLevel);
                stakingManager.addTokensToStaking(nftId, totalTokens);
            }
        }

        return freeMFITokensReceived;
    }

    function setReferralLink(uint256 nftId, string calldata newReferralLink) external override {
        verifySenderAndNFT(nftId);

        rebaseStaking();

        IAccountToken accountTokens = getAccountToken();
        accountTokens.setReferralLink(nftId, newReferralLink);
    }

    function liquidateAccount(uint256 nftId) external override {
        verifySenderAndNFT(nftId);

        rebaseStaking();

        IAccountToken accountTokens = getAccountToken();
        IStakingManagerV3 stakingManager = getStakingManager();

        bool liquidated = accountTokens.requestLiquidation(nftId);
        if (liquidated) {

            IRewardDistributor rewardDistributor = getRewardDistributor();

            rewardDistributor.liquidateAccount(nftId);
            stakingManager.liquidateAccount(nftId, msg.sender);

            emit AccountLiquidated(nftId);
        } else {

            stakingManager.pauseStaking(nftId);

            emit AccountLiquidationStarted(nftId);
        }
    }

    function cancelLiquidation(uint256 nftId) external override {
        verifySenderAndNFT(nftId);

        rebaseStaking();

        IAccountToken accountTokens = getAccountToken();
        accountTokens.cancelLiquidation(nftId);

        IStakingManagerV3 stakingManager = getStakingManager();
        stakingManager.resumeStaking(nftId);

        emit AccountLiquidationCanceled(nftId);
    }

    function resumeStaking(uint256 nftId) external override {
        verifySenderAndNFT(nftId);

        rebaseStaking();

        IAccountToken accountTokens = getAccountToken();
        IAccountToken.LiquidationStatus liquidationStatus = accountTokens.getLiquidationInfo(nftId).status;

        require(liquidationStatus == IAccountToken.LiquidationStatus.NOT_REQUESTED, "Liquidation is in progress");

        IStakingManagerV3 stakingManager = getStakingManager();
        stakingManager.resumeStaking(nftId);

        emit StakingResumed(nftId);
    }

    function setUserConfigUintValue(uint256 nftId, string memory key, uint256 value) external override {
        verifySenderAndNFT(nftId);

        rebaseStaking();

        getUserConfig().setUserConfigUintValue(nftId, key, value);
    }

    function setUserConfigStringValue(uint256 nftId, string memory key, string memory value) external override {
        verifySenderAndNFT(nftId);

        rebaseStaking();

        getUserConfig().setUserConfigStringValue(nftId, key, value);
    }

    //-------------------------

    //Staking
    function stakeTokens(uint256 nftId, uint256 numberOfTokens) external override {
        verifySenderAndNFT(nftId);

        rebaseStaking();

        //Add tokens to existing staking account
        IStakingManagerV3 stakingManager = getStakingManager();
        stakingManager.addTokensToStaking(nftId, numberOfTokens);

        //Transfer MFI from user to staking manager
        IERC20(contractRegistry.getContractAddress(MFI_HASH)).safeTransferFrom(msg.sender, address(stakingManager), numberOfTokens);

        emit TokensStaked(nftId, numberOfTokens);
    }
    //-------------------------

    //Bonding

    function buyTokens(uint256 nftId, uint256 primaryStableCoinPrice, uint256 minTokensOut, IERC20 paymentCurrency) external payable {
        onlyEOA();
        verifySenderAndNFT(nftId);

        rebaseStaking();

        uint256 currentLevel = getAccountToken().getAccountLevel(nftId);

        uint256 numberOfTokens = 0;

        uint256 primaryStableCoinPriceWithConversionFee = (primaryStableCoinPrice * 1005) / 1000;

        if (msg.value > 0) {

            IPancakeRouter02 pancakeRouter = getPancakeRouter();

            address[] memory path = new address[](2);
            path[0] = pancakeRouter.WETH();
            path[1] = contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH);

            uint256 neededBNB = pancakeRouter.getAmountsIn(primaryStableCoinPriceWithConversionFee, path)[0];

            require(msg.value >= neededBNB, "insufficient msg value");

            if (msg.value > neededBNB) {
                payable(msg.sender).sendValue(msg.value - neededBNB);
            }

            pancakeRouter.swapExactETHForTokens{value : neededBNB}(primaryStableCoinPriceWithConversionFee, path, contractRegistry.getContractAddress(TREASURY_HASH), block.timestamp);

            numberOfTokens = getTokenCollector().getTokens(primaryStableCoinPrice, minTokensOut);

        } else if (address(paymentCurrency) == contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH)) {
            //Transfer payment from user to treasury
            getPrimaryStableCoin().safeTransferFrom(msg.sender, contractRegistry.getContractAddress(TREASURY_HASH), primaryStableCoinPrice);
            numberOfTokens = getTokenCollector().getTokens(primaryStableCoinPrice, minTokensOut);
        } else {
            address[] memory path = new address[](2);
            path[0] = address(paymentCurrency);
            path[1] = contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH);

            IPancakeRouter02 pancakeRouter = getPancakeRouter();

            uint256[] memory amountsIn = pancakeRouter.getAmountsIn(primaryStableCoinPriceWithConversionFee, path);

            paymentCurrency.safeTransferFrom(msg.sender, address(this), amountsIn[0]);
            paymentCurrency.safeApprove(address(pancakeRouter), amountsIn[0]);
            pancakeRouter.swapExactTokensForTokens(amountsIn[0], primaryStableCoinPriceWithConversionFee, path, contractRegistry.getContractAddress(TREASURY_HASH), block.timestamp);

            numberOfTokens = getTokenCollector().getTokens(primaryStableCoinPrice, minTokensOut);
        }


        //Add tokens to existing staking account
        getStakingManager().addTokensToStaking(nftId, numberOfTokens);

        //Distribute token buying rewards
        getRewardDistributor().distributeRewards(primaryStableCoinPrice, 1, nftId, currentLevel);

        emit TokensBought(nftId, primaryStableCoinPrice, numberOfTokens, currentLevel);
    }

    //-------------------------

    function totalLevels() external view returns (uint256) {
        return levelPricesInPrimaryStableCoin.length;
    }

    function rebaseStaking() public {
        getStakingManager().rebase();
    }

    function destroyContract(address payable to) external override {
        onlyTreasury();
        to.sendValue(address(this).balance);
    }
}