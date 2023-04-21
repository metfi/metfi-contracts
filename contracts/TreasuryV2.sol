// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract TreasuryV2 is ITreasuryV2, ContractRegistryUser {

    using SafeERC20 for IERC20;
    using SafeERC20 for IMETFI;
    using Address for address payable;

    struct LPTokenSettings {
        string liquidityController;
        address baseToken;
        bool reserveToken;
    }

    struct LiquidationTokenInfo {
        address token;
        uint256 totalAmount;
    }

    address[] public reserveTokens;
    LPTokenSettings[] public lpTokens;
    IValueCalculator[] public valueCalculators;
    address[] public liquidityTokens;

    uint256 public totalRewardsPaid;

    bool public inLiquidation = false;
    uint256 public totalMETFIInLiquidation;
    address payable public liquidationAddress;
    uint256 public liquidationBNBAmount;
    LiquidationTokenInfo[] public liquidationTokens;


    //----------------- Access control ------------------------------------------

    function notInLiquidation() internal view {
        require(!inLiquidation, "liquidation active");
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry, uint256 totalRewardsPaidPrevious) ContractRegistryUser(_contractRegistry) {
        reserveTokens.push(contractRegistry.getContractAddress(PRIMARY_STABLECOIN_HASH));
        totalRewardsPaid = totalRewardsPaidPrevious;
    }

    function sendReward(uint256 nftId, uint256 amount) external override {
        onlyRewardDistributor();
        notInLiquidation();

        totalRewardsPaid += amount;

        if (nftId == 1) return;

        getPrimaryStableCoin().approve(contractRegistry.getContractAddress(REWARD_CONVERTER_HASH), amount);

        getRewardConverter().sendReward(nftId, getPrimaryStableCoin(), amount);

        emit RewardsSent(nftId, amount);
    }

    function getTotalRewardsPaid() external view override returns (uint256) {
        return totalRewardsPaid;
    }

    function getTokensForCollector(address token, uint256 amount, address to) external override {
        notInLiquidation();
        onlyTokenCollector();
        IERC20(token).safeTransfer(to, amount);
    }

    function getValue() public view override returns (uint256 totalValue, uint256 riskFreeValue) {


        for (uint256 x = 0; x < reserveTokens.length; x++) {
            riskFreeValue += IERC20(reserveTokens[x]).balanceOf(address(this)) * (10 ** 18) / IERC20Metadata(reserveTokens[x]).decimals();
        }

        for (uint256 x = 0; x < lpTokens.length; x++) {

            ILiquidityController controller = contractRegistry.getLiquidityController(lpTokens[x].liquidityController);
            uint256 claimableTokens = controller.claimableTokensFromTreasuryLPTokens(lpTokens[x].baseToken);

            if (lpTokens[x].reserveToken) {
                riskFreeValue += claimableTokens * (10 ** 18) / IERC20Metadata(lpTokens[x].baseToken).decimals();
            } else {
                totalValue += getPriceCalculator(lpTokens[x].baseToken).priceForTokens(claimableTokens);
            }
        }

        for (uint256 x = 0; x < liquidityTokens.length; x++) {
            totalValue += getPriceCalculator(liquidityTokens[x]).priceForTokens(IERC20(liquidityTokens[x]).balanceOf(address(this)));
        }

        totalValue += riskFreeValue;

        for (uint256 x = 0; x < valueCalculators.length; x++) {
            (uint256 calculatorTotalValue, uint256 calculatorRiskFreeValue) = valueCalculators[x].calculateValue();
            totalValue += calculatorTotalValue;
            riskFreeValue += calculatorRiskFreeValue;
        }


        return (totalValue, riskFreeValue);
    }

    function isLPTokenTracked(address token, string calldata liquidityControllerName) public view returns (bool) {
        for (uint256 x = 0; x < lpTokens.length; x++) {
            if (lpTokens[x].baseToken == token && keccak256(abi.encodePacked(lpTokens[x].liquidityController)) == keccak256(abi.encodePacked(liquidityControllerName))) return true;
        }

        return false;
    }

    function getTokenType(address token) public view returns (TokenType tokenType, bool found) {

        for (uint256 x = 0; x < reserveTokens.length; x++) {
            if (reserveTokens[x] == token) return (TokenType.RESERVE_TOKEN, true);
        }

        for (uint256 x = 0; x < liquidityTokens.length; x++) {
            if (liquidityTokens[x] == token) return (TokenType.LIQUIDITY_TOKEN, true);
        }

        return (TokenType.LIQUIDITY_TOKEN, false);
    }

    function startTrackingToken(TokenType tokenType, address token, bool isReserveToken, string calldata liquidityControllerName) external {
        onlyRealmGuardian();
        notInLiquidation();

        _startTrackingToken(tokenType, token, isReserveToken, liquidityControllerName);
    }

    function _startTrackingToken(TokenType tokenType, address token, bool isReserveToken, string calldata liquidityControllerName) internal {

        if (tokenType == TokenType.RESERVE_TOKEN) {

            for (uint256 x = 0; x < reserveTokens.length; x++) {
                if (reserveTokens[x] == token) return;
            }

            reserveTokens.push(token);
        } else if (tokenType == TokenType.LIQUIDITY_TOKEN) {

            for (uint256 x = 0; x < liquidityTokens.length; x++) {
                if (liquidityTokens[x] == token) return;
            }

            liquidityTokens.push(token);
        } else if (tokenType == TokenType.LP_TOKEN) {

            for (uint256 x = 0; x < lpTokens.length; x++) {
                if (lpTokens[x].baseToken == token) return;
            }

            if (!isReserveToken) {
                require(contractRegistry.getPriceCalculator(token) != address(0), "no price calculator");
            }

            lpTokens.push(LPTokenSettings(liquidityControllerName, token, isReserveToken));
        }
    }

    function stopTrackingToken(TokenType tokenType, address token, string calldata liquidityControllerName) external {
        onlyRealmGuardian();
        notInLiquidation();
        _stopTrackingToken(tokenType, token, liquidityControllerName);
    }

    function _stopTrackingToken(TokenType tokenType, address token, string calldata liquidityControllerName) internal {

        if (tokenType == TokenType.RESERVE_TOKEN) {
            for (uint256 x = 0; x < reserveTokens.length; x++) {
                if (reserveTokens[x] == token) {
                    reserveTokens[x] = reserveTokens[reserveTokens.length - 1];
                    reserveTokens.pop();
                    break;
                }
            }
        } else if (tokenType == TokenType.LIQUIDITY_TOKEN) {
            for (uint256 x = 0; x < liquidityTokens.length; x++) {
                if (liquidityTokens[x] == token) {
                    liquidityTokens[x] = liquidityTokens[liquidityTokens.length - 1];
                    liquidityTokens.pop();
                    break;
                }
            }
        } else if (tokenType == TokenType.LP_TOKEN) {
            for (uint256 x = 0; x < lpTokens.length; x++) {
                if (lpTokens[x].baseToken == token && keccak256(abi.encodePacked(lpTokens[x].liquidityController)) == keccak256(abi.encodePacked(liquidityControllerName))) {
                    lpTokens[x] = lpTokens[lpTokens.length - 1];
                    lpTokens.pop();
                    break;
                }
            }
        }

    }

    function provideLiquidity(string calldata controllerName, address tokenToUse, uint256 amount, uint256 minMETFI) external {
        onlyRealmGuardian();
        notInLiquidation();

        ILiquidityController controller = contractRegistry.getLiquidityController(controllerName);

        uint256 neededMETFI = controller.mfiRequiredForProvidingLiquidity(tokenToUse, amount, minMETFI);
        // Take from METFIVault
        getMETFIVault().withdrawMETFI(address(controller), neededMETFI);

        IERC20(tokenToUse).safeTransfer(address(controller), amount);

        controller.provideLiquidity(tokenToUse, amount, minMETFI);

        IMETFI metfi = getMETFI();

        if (metfi.balanceOf(address(this)) > 0) {
            metfi.safeTransfer(address(getMETFIVault()), metfi.balanceOf(address(this)));
        }

        if (!isLPTokenTracked(tokenToUse, controllerName)) {

            (TokenType tokenType, bool found) = getTokenType(tokenToUse);
            if (found) {
                _startTrackingToken(TokenType.LP_TOKEN, tokenToUse, tokenType == TokenType.RESERVE_TOKEN, controllerName);
            }

        }
    }

    function removeLiquidity(string calldata controllerName, address tokenToUse, uint256 lpTokenAmount, uint256 tokenMin) external {
        onlyRealmGuardian();
        notInLiquidation();

        ILiquidityController controller = contractRegistry.getLiquidityController(controllerName);
        IMETFI metfi = getMETFI();

        IERC20 lpToken = IERC20(controller.getLPTokenAddress(tokenToUse));
        lpToken.safeTransfer(address(controller), lpTokenAmount);

        controller.removeLiquidity(tokenToUse, lpTokenAmount, tokenMin);

        metfi.safeTransfer(address(getMETFIVault()), metfi.balanceOf(address(this)));

        if (lpToken.balanceOf(address(this)) == 0 && isLPTokenTracked(tokenToUse, controllerName)) {
            _stopTrackingToken(TokenType.LP_TOKEN, tokenToUse, controllerName);
        }
    }

    function collectLostTokensFromContract(address token, address metFiContract) external {
        onlyRealmGuardian();
        notInLiquidation();
        ILostTokenProvider(metFiContract).getLostTokens(token);
    }

    function addValueCalculator(address valueCalculator) external {
        onlyRealmGuardian();

        valueCalculators.push(IValueCalculator(valueCalculator));
    }

    function removeValueCalculator(address valueCalculator) external {

        onlyRealmGuardian();

        for (uint256 x = 0; x < valueCalculators.length; x++) {
            if (address(valueCalculators[x]) == valueCalculator) {
                valueCalculators[x] = valueCalculators[valueCalculators.length - 1];
                valueCalculators.pop();
                break;
            }
        }
    }

    function manage(address to, address token, uint256 amount) external {
        onlyCoinMaster();
        notInLiquidation();
        IERC20(token).safeTransfer(to, amount);
    }

    //Deposit token and get back METFI for market price
    function deposit(address token, uint256 amount) external {
        onlyCoinMaster();
        notInLiquidation();

        IPriceCalculator tokenPriceCalculator = getPriceCalculator(token);
        IPriceCalculator metfiPriceCalculator = getPriceCalculator(address(getMETFI()));

        uint256 tokenValue = tokenPriceCalculator.priceForTokens(amount);
        uint256 metfiOut = metfiPriceCalculator.tokensForPrice(tokenValue);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        getMETFIVault().withdrawMETFI(msg.sender, metfiOut);
    }

    //Buy back and send METFI to vault
    function buyBackMETFI(string memory buybackControllerName, address tokenAddress, uint256 tokenAmount, uint256 minMETFIOut) external {
        onlyCoinMaster();
        notInLiquidation();

        IMETFI metfi = getMETFI();
        IERC20 token = IERC20(tokenAddress);
        IBuybackController buybackController = contractRegistry.getBuybackController(buybackControllerName);

        uint256 initialMETFIBalance = metfi.balanceOf(address(this));

        token.safeTransfer(address(buybackController), tokenAmount);
        buybackController.buyBackMFI(tokenAddress, tokenAmount, minMETFIOut);

        require(metfi.balanceOf(address(this)) > (initialMETFIBalance + minMETFIOut), "Not enough METFI received");

        metfi.safeTransfer(address(getMETFIVault()), metfi.balanceOf(address(this)));

    }

    function startSystemLiquidation(address payable claimEthTo) external {
        onlyRealmGuardian();
        notInLiquidation();

        for (uint256 x = 0; x < lpTokens.length; x++) {

            ILiquidityController controller = contractRegistry.getLiquidityController(lpTokens[x].liquidityController);
            IERC20 lpToken = IERC20(controller.getLPTokenAddress(lpTokens[x].baseToken));

            uint256 lpTokenAmount = lpToken.balanceOf(address(this));
            uint256 tokensOut = controller.claimableTokensFromTreasuryLPTokens(lpTokens[x].baseToken);

            lpToken.safeTransfer(address(controller), lpTokenAmount);
            controller.removeLiquidity(lpTokens[x].baseToken, lpTokenAmount, tokensOut);
        }

        IMETFI metfi = getMETFI();

        getMETFIVault().withdrawMETFI(address(this), metfi.balanceOf(address(getMETFIVault())));
        getMETFIStakingPool().withdrawMETFI(address(this), metfi.balanceOf(address(getMETFIStakingPool())));

        if (metfi.balanceOf(address(this)) > 0) {
            metfi.burn(metfi.balanceOf(address(this)));
        }

        totalMETFIInLiquidation = getStakingManager().enterLiquidation();

        for (uint256 x = 0; x < reserveTokens.length; x++) {
            liquidationTokens.push(LiquidationTokenInfo(reserveTokens[x], IERC20(reserveTokens[x]).balanceOf(address(this))));
        }

        for (uint256 x = 0; x < liquidityTokens.length; x++) {
            liquidationTokens.push(LiquidationTokenInfo(liquidityTokens[x], IERC20(liquidityTokens[x]).balanceOf(address(this))));
        }

        liquidationBNBAmount = address(this).balance;

        inLiquidation = true;
        liquidationAddress = claimEthTo;
    }

    function claimLiquidationShare() external {

        require(inLiquidation, "not in liquidation");

        IAccountToken accountToken = getAccountToken();
        (uint256[] memory addressNFTs, uint256 numberOfActive) = accountToken.getAddressNFTs(msg.sender);

        for (uint256 x = 0; x < numberOfActive; x++) {
            _claimLiquidationShare(addressNFTs[x]);
        }

        if (accountToken.totalSupply() == 1) {

            //Only DAO token is left

            IDestroyableContract(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).destroyContract(liquidationAddress);
            IDestroyableContract(contractRegistry.getContractAddress(STAKING_MANAGER_HASH)).destroyContract(liquidationAddress);

            if (address(this).balance > 0) {
                liquidationAddress.sendValue(address(this).balance);
            }
        }
    }

    function _claimLiquidationShare(uint256 nftId) internal {

        IAccountToken accountToken = getAccountToken();
        address payable owner = payable(accountToken.ownerOf(nftId));

        IStakingManagerV3 stakingManger = getStakingManager();
        uint256 userMETFI = stakingManger.getAccountTokens(nftId);

        for (uint256 x = 0; x < liquidationTokens.length; x++) {
            uint256 tokenAmount = liquidationTokens[x].totalAmount * userMETFI / totalMETFIInLiquidation;
            IERC20(liquidationTokens[x].token).safeTransfer(owner, tokenAmount);
        }

        if(liquidationBNBAmount > 0) {
            owner.sendValue(liquidationBNBAmount * userMETFI / totalMETFIInLiquidation);
        }

        getMETFI().safeTransfer(owner, userMETFI);

        accountToken.liquidateAccount(nftId);
    }

    function getLostTokens(address) public pure override {
        revert("disabled");
    }
}