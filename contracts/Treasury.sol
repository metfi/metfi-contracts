// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./interfaces/ITreasury.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./MFI.sol";
import "./interfaces/IAccountToken.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IPriceCalculator.sol";
import "./interfaces/ILiquidityController.sol";
import "./interfaces/ITreasuryAllocator.sol";
import "./interfaces/IDestroyableContract.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/ITreasuryExtender.sol";

contract Treasury is ITreasury, IERC721Receiver {

    using SafeERC20 for IERC20;

    IERC20 public busd;
    uint256 public totalRewardsPaid;

    enum TokenType {
        RESERVE_TOKEN,
        LP_TOKEN,
        LIQUIDITY_TOKEN
    }

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
    address[] public liquidityTokens;


    bool public inLiquidation = false;
    uint256 public totalMFIInLiquidation;
    address payable public liquidationAddress;
    LiquidationTokenInfo[] public liquidationTokens;

    //Errors
    string internal ErrNoPriceCalc = "no price calculator";


    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 immutable MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 immutable STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));
    bytes32 immutable REWARD_DISTRIBUTOR_HASH = keccak256(abi.encodePacked('reward_distributor'));
    bytes32 immutable TOKEN_COLLECTOR_HASH = keccak256(abi.encodePacked('token_collector'));
    bytes32 immutable ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));
    bytes32 immutable PLATFORM_VIEW_HASH = keccak256(abi.encodePacked('platform_view'));
    bytes32 immutable ROUTER_HASH = keccak256(abi.encodePacked('router'));
    bytes32 immutable TREASURY_EXTENDER_HASH = keccak256(abi.encodePacked('treasury_extender'));

    modifier onlyRewardDistributor() {
        require(msg.sender == contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
        _;
    }

    modifier onlyStakingManager() {
        require(msg.sender == contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
        _;
    }

    modifier onlyTokenCollector() {
        require(msg.sender == contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH));
        _;
    }

    modifier onlyRealmGuardian() {
        require(contractRegistry.isRealmGuardian(msg.sender));
        _;
    }

    modifier onlyCoinMaster() {
        require(contractRegistry.isCoinMaster(msg.sender));
        _;
    }

    modifier extenderOrCoinMaster() {
        require(contractRegistry.isCoinMaster(msg.sender) || msg.sender == contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH));
        _;
    }

    modifier notInLiquidation() {
        require(!inLiquidation, "liquidation active");
        _;
    }
    //---------------------------------------------------------------------------

    constructor(
        IContractRegistry _contractRegistry,
        IERC20 _busd
    ) {
        contractRegistry = _contractRegistry;
        busd = _busd;
        reserveTokens.push(address(busd));
    }

    function distributeStakingRewards(uint256 amount) external onlyStakingManager notInLiquidation override {

        MetFi MFI = MetFi(contractRegistry.getContractAddress(MFI_HASH));
        MFI.mint(contractRegistry.getContractAddress(STAKING_MANAGER_HASH), amount);

        emit StakingRewardsDistributed(amount);
    }

    function sendReward(uint256 nftId, uint256 amount) external onlyRewardDistributor notInLiquidation override {

        totalRewardsPaid += amount;

        if (nftId == 1) return;

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));

        busd.safeTransfer(accountTokens.ownerOf(nftId), amount);

        emit RewardsSent(nftId, amount);
    }

    function getTotalRewardsPaid() public view override returns (uint256) {
        return totalRewardsPaid;
    }

    function getTokensForCollector(address token, uint256 amount, address to) external onlyTokenCollector notInLiquidation override {
        IERC20(token).safeTransfer(to, amount);
    }

    function getValue() public view override returns (uint256 totalValue, uint256 riskFreeValue) {

        for (uint256 x = 0; x < reserveTokens.length; x++) {
            riskFreeValue += IERC20(reserveTokens[x]).balanceOf(address(this));
        }

        for (uint256 x = 0; x < lpTokens.length; x++) {

            ILiquidityController controller = contractRegistry.getLiquidityController(lpTokens[x].liquidityController);
            uint256 claimableTokens = controller.claimableTokensFromTreasuryLPTokens(lpTokens[x].baseToken);

            if (lpTokens[x].reserveToken) {
                riskFreeValue += claimableTokens;
            } else {
                totalValue += IPriceCalculator(contractRegistry.getPriceCalculator(lpTokens[x].baseToken)).priceForTokens(claimableTokens);
            }
        }

        for (uint256 x = 0; x < liquidityTokens.length; x++) {
            totalValue += IPriceCalculator(contractRegistry.getPriceCalculator(liquidityTokens[x])).priceForTokens(IERC20(liquidityTokens[x]).balanceOf(address(this)));
        }

        (uint256 allocatorRiskFreeValue, uint256 allocatorTotalValue) = ITreasuryExtender(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).getValue();
        riskFreeValue += allocatorRiskFreeValue;
        totalValue += allocatorTotalValue;

        totalValue += riskFreeValue;

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

    function startTrackingToken(TokenType tokenType, address token, bool isReserveToken, string calldata liquidityControllerName) external onlyRealmGuardian notInLiquidation {
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

            require(contractRegistry.getPriceCalculator(token) != address(0), ErrNoPriceCalc);

            liquidityTokens.push(token);
        } else if (tokenType == TokenType.LP_TOKEN) {

            for (uint256 x = 0; x < lpTokens.length; x++) {
                if (lpTokens[x].baseToken == token) return;
            }

            if (!isReserveToken) {
                require(contractRegistry.getPriceCalculator(token) != address(0), ErrNoPriceCalc);
            }

            lpTokens.push(LPTokenSettings(liquidityControllerName, token, isReserveToken));
        }
    }

    function stopTrackingToken(TokenType tokenType, address token, string calldata liquidityControllerName) external onlyRealmGuardian notInLiquidation {
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

    function provideLiquidity(string calldata controllerName, address tokenToUse, uint256 amount, uint256 MFIMin) external onlyRealmGuardian notInLiquidation {

        ILiquidityController controller = contractRegistry.getLiquidityController(controllerName);
        MetFi MFI = MetFi(contractRegistry.getContractAddress(MFI_HASH));

        uint256 mfiNeeded = controller.mfiRequiredForProvidingLiquidity(tokenToUse, amount, MFIMin);
        MFI.mint(address(controller), mfiNeeded);

        IERC20(tokenToUse).safeTransfer(address(controller), amount);

        controller.provideLiquidity(tokenToUse, amount, MFIMin);

        if (IERC20(address(MFI)).balanceOf(address(this)) > 0) {
            MFI.burn(address(this), IERC20(address(MFI)).balanceOf(address(this)));
        }

        if (!isLPTokenTracked(tokenToUse, controllerName)) {

            (TokenType tokenType, bool found) = getTokenType(tokenToUse);
            if (found) {
                _startTrackingToken(TokenType.LP_TOKEN, tokenToUse, tokenType == TokenType.RESERVE_TOKEN, controllerName);
            }

        }
    }

    function removeLiquidity(string calldata controllerName, address tokenToUse, uint256 lpTokenAmount, uint256 tokenMin) external onlyRealmGuardian notInLiquidation {

        ILiquidityController controller = contractRegistry.getLiquidityController(controllerName);
        MetFi MFI = MetFi(contractRegistry.getContractAddress(MFI_HASH));

        IERC20 lpToken = IERC20(controller.getLPTokenAddress(tokenToUse));
        lpToken.safeTransfer(address(controller), lpTokenAmount);

        controller.removeLiquidity(tokenToUse, lpTokenAmount, tokenMin);

        MFI.burn(address(this), IERC20(address(MFI)).balanceOf(address(this)));

        if (lpToken.balanceOf(address(this)) == 0 && isLPTokenTracked(tokenToUse, controllerName)) {
            _stopTrackingToken(TokenType.LP_TOKEN, tokenToUse, controllerName);
        }
    }

    function collectLostTokensFromContract(address token, address metFiContract) external onlyRealmGuardian notInLiquidation {
        ILostTokenProvider(metFiContract).getLostTokens(token);
    }

    //Allow extender to take take tokens for allocators
    function manage(address to, address token, uint256 amount) external extenderOrCoinMaster notInLiquidation {
        IERC20(token).safeTransfer(to, amount);
    }

    //Deposit token and get back MFI for market price
    function deposit(address token, uint256 amount) external onlyCoinMaster notInLiquidation {

        IPriceCalculator priceCalculator = IPriceCalculator(contractRegistry.getPriceCalculator(token));
        require(address(priceCalculator) != address(0), ErrNoPriceCalc);

        uint256 tokenValue = priceCalculator.tokensForPrice(amount);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        MetFi MFI = MetFi(contractRegistry.getContractAddress(MFI_HASH));
        MFI.mint(msg.sender, tokenValue);
    }

    //Buy back and burn MFI from exchange
    function buyBackMFI(string memory buybackControllerName, address tokenAddress, uint256 tokenAmount, uint256 minMFIOut) external onlyCoinMaster notInLiquidation {

        IERC20 MFI = IERC20(contractRegistry.getContractAddress(MFI_HASH));
        IERC20 token = IERC20(tokenAddress);
        IBuybackController buybackController = contractRegistry.getBuybackController(buybackControllerName);

        uint256 initialMFIBalance = MFI.balanceOf(address(this));

        token.safeTransfer(address(buybackController), tokenAmount);
        buybackController.buyBackMFI(tokenAddress, tokenAmount, minMFIOut);

        require(MFI.balanceOf(address(this)) > (initialMFIBalance + minMFIOut), "Not enough MFI received");

        MetFi(address(MFI)).burn(address(this), MFI.balanceOf(address(this)));
    }

    function startSystemLiquidation(address payable claimEthTo, uint256 matrixLevels, string[] memory liquidityControllers, string[] memory buybackControllers, address[] memory priceCalcTokens) external onlyRealmGuardian notInLiquidation {

        for (uint256 x = 0; x < lpTokens.length; x++) {

            ILiquidityController controller = contractRegistry.getLiquidityController(lpTokens[x].liquidityController);
            IERC20 lpToken = IERC20(controller.getLPTokenAddress(lpTokens[x].baseToken));

            uint256 lpTokenAmount = lpToken.balanceOf(address(this));
            uint256 tokensOut = controller.claimableTokensFromTreasuryLPTokens(lpTokens[x].baseToken);

            lpToken.safeTransfer(address(controller), lpTokenAmount);
            controller.removeLiquidity(lpTokens[x].baseToken, lpTokenAmount, tokensOut);
        }

        MetFi MFI = MetFi(contractRegistry.getContractAddress(MFI_HASH));
        if (IERC20(address(MFI)).balanceOf(address(this)) > 0) {
            MFI.burn(address(this), IERC20(address(MFI)).balanceOf(address(this)));
        }

        IDestroyableContract(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)).destroyContract(claimEthTo);
        IDestroyableContract(contractRegistry.getContractAddress(ROUTER_HASH)).destroyContract(claimEthTo);
        IDestroyableContract(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH)).destroyContract(claimEthTo);
        IDestroyableContract(contractRegistry.getContractAddress(PLATFORM_VIEW_HASH)).destroyContract(claimEthTo);
        IDestroyableContract(contractRegistry.getContractAddress(TREASURY_EXTENDER_HASH)).destroyContract(claimEthTo);

        for (uint256 x = 0; x < matrixLevels; x++) {
            IDestroyableContract(address(contractRegistry.getMatrix(x))).destroyContract(claimEthTo);
        }

        for (uint256 x = 0; x < liquidityControllers.length; x++) {
            IDestroyableContract(address(contractRegistry.getLiquidityController(liquidityControllers[x]))).destroyContract(claimEthTo);
        }

        for (uint256 x = 0; x < buybackControllers.length; x++) {
            IDestroyableContract(address(contractRegistry.getBuybackController(buybackControllers[x]))).destroyContract(claimEthTo);
        }

        for (uint256 x = 0; x < priceCalcTokens.length; x++) {
            IDestroyableContract(contractRegistry.getPriceCalculator(priceCalcTokens[x])).destroyContract(claimEthTo);
        }

        totalMFIInLiquidation = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH)).enterLiquidation();

        for(uint256 x = 0; x < reserveTokens.length; x++) {
            liquidationTokens.push(LiquidationTokenInfo(reserveTokens[x], IERC20(reserveTokens[x]).balanceOf(address(this))));
        }

        for(uint256 x = 0; x < liquidityTokens.length; x++) {
            liquidationTokens.push(LiquidationTokenInfo(liquidityTokens[x], IERC20(liquidityTokens[x]).balanceOf(address(this))));
        }

        inLiquidation = true;
        liquidationAddress = claimEthTo;
    }

    function claimLiquidationShare() external {

        require(inLiquidation, "not in liquidation");

        IAccountToken accountToken = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        (uint256[] memory addressNFTs, uint256 numberOfActive) = accountToken.getAddressNFTs(msg.sender);

        for(uint256 x = 0; x < numberOfActive; x++) {
            _claimLiquidationShare(addressNFTs[x]);
        }

        if (IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).totalSupply() == 1) {

            //Only DAO token is left

            IDestroyableContract(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).destroyContract(liquidationAddress);
            IDestroyableContract(contractRegistry.getContractAddress(STAKING_MANAGER_HASH)).destroyContract(liquidationAddress);

            selfdestruct(liquidationAddress);
        }
    }

    function _claimLiquidationShare(uint256 nftId) internal {

        IAccountToken accountToken = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        address owner = accountToken.ownerOf(nftId);

        IStakingManager stakingManger = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
        uint256 userMFI = stakingManger.getAccountTokens(nftId);

        for(uint256 x = 0; x < liquidationTokens.length; x++) {
            uint256 tokenAmount = liquidationTokens[x].totalAmount * userMFI / totalMFIInLiquidation;
            IERC20(liquidationTokens[x].token).safeTransfer(owner, tokenAmount);
        }

        IERC20(contractRegistry.getContractAddress(MFI_HASH)).safeTransfer(owner, userMFI);

        accountToken.liquidateAccount(nftId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}