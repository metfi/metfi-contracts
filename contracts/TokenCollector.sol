// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPriceCalculator.sol";
import "./MFI.sol";
import "./interfaces/ITokenCollector.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";

contract TokenCollector is ITokenCollector, ILostTokenProvider, IDestroyableContract {

    using SafeERC20 for IERC20;

    IERC20 public busd;

    CollectionType public collectionType;
    PriceCalculationType public priceCalculationType;

    uint256 additionalTokensPercentage = 10;
    uint256 bonusTokenPercentageFromSwap = 100;

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant ROUTER_HASH = keccak256(abi.encodePacked('router'));
    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant PANCAKE_ROUTER_HASH = keccak256(abi.encodePacked('pancake_router'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));

    modifier onlyRouter() {
        require(msg.sender == contractRegistry.getContractAddress(ROUTER_HASH));
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }

    modifier onlyRealmGuardian() {
        require(contractRegistry.isRealmGuardian(msg.sender));
        _;
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry, IERC20 _busd) {

        contractRegistry = _contractRegistry;

        collectionType = CollectionType.MINTING;
        busd = _busd;
    }

    function getBonusTokens(uint256 busdPrice) public onlyRouter override returns (uint256) {

        IPriceCalculator priceCalc = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(MFI_HASH)));
        IERC20 MFI = IERC20(contractRegistry.getContractAddress(MFI_HASH));

        address to = contractRegistry.getContractAddress(STAKING_MANAGER_HASH);

        uint256 tokensForPrice = priceCalc.tokensForPrice(busdPrice);
        uint256 tokensFromSwap = (tokensForPrice * bonusTokenPercentageFromSwap) / 100;
        uint256 tokensToMint = tokensForPrice - tokensFromSwap;

        if (tokensToMint > 0) {
            MetFi(address(MFI)).mint(to, tokensToMint);
        }

        if (tokensFromSwap > 0) {

            uint256 valueFromSwap = (busdPrice * bonusTokenPercentageFromSwap) / 100;

            ITreasury(contractRegistry.getContractAddress(TREASURY_HASH)).getTokensForCollector(address(busd), valueFromSwap, address(this));
            IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));

            busd.approve(address(pancakeRouter), valueFromSwap);

            address[] memory path = new address[](2);
            (path[0], path[1]) = (address(busd), address(MFI));

            uint256[] memory amounts = pancakeRouter.swapExactTokensForTokens(
                valueFromSwap,
                tokensFromSwap,
                path,
                to,
                block.timestamp
            );

            tokensForPrice = tokensToMint + amounts[amounts.length - 1];
        }

        emit CollectedBonusTokens(busdPrice, tokensForPrice);

        return tokensForPrice;
    }

    function getTokens(uint256 busdPrice, uint256 minTokensOut) public onlyRouter override returns (uint256){

        IPriceCalculator priceCalc = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(MFI_HASH)));
        IERC20 MFI = IERC20(contractRegistry.getContractAddress(MFI_HASH));

        address to = contractRegistry.getContractAddress(STAKING_MANAGER_HASH);
        uint256 tokensForPrice = priceCalc.tokensForPrice(busdPrice);

        if (collectionType == CollectionType.MINTING) {

            if (priceCalculationType == PriceCalculationType.TOKEN_PRICE_BASED) {
                tokensForPrice = (busdPrice * (10 ** 18)) / priceCalc.getPriceInUSD();
            }

            tokensForPrice = tokensForPrice * (100 + additionalTokensPercentage) / 100;

            if (minTokensOut > 0) {
                require(tokensForPrice >= minTokensOut, "Slippage exceeded");
            }

            MetFi(address(MFI)).mint(to, tokensForPrice);

            emit CollectedTokens(busdPrice, tokensForPrice, uint256(collectionType), uint256(priceCalculationType));

            return tokensForPrice;

        } else if (collectionType == CollectionType.SWAP) {

            //Mint 15% of tokens to be able to cover rewards
            uint256 valueFromSwap = (busdPrice * 85) / 100;
            uint256 minTokensOutSwap = (minTokensOut * 85) / 100;

            ITreasury(contractRegistry.getContractAddress(TREASURY_HASH)).getTokensForCollector(address(busd), valueFromSwap, address(this));

            IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));

            busd.approve(address(pancakeRouter), valueFromSwap);

            address[] memory path = new address[](2);
            (path[0], path[1]) = (address(busd), address(MFI));

            //Swap 85% of tokens directly to staking manager
            uint256[] memory amounts = pancakeRouter.swapExactTokensForTokens(
                valueFromSwap,
                minTokensOutSwap,
                path,
                to,
                block.timestamp
            );

            uint256 receivedTokens = amounts[amounts.length - 1];
            uint256 tokensToMint = (receivedTokens * 15) / 85;

            //Mint 15% of tokens to staking manager
            MetFi(address(MFI)).mint(to, tokensToMint);

            uint256 tokensCollected = receivedTokens + tokensToMint;
            require(tokensCollected >= minTokensOut, "Slippage exceeded");

            emit CollectedTokens(busdPrice, tokensCollected, uint256(collectionType), uint256(priceCalculationType));

            return tokensCollected;
        } else {
            revert("Broken config");
        }
    }

    function getCollectionType() public view override returns (CollectionType) {
        return collectionType;
    }

    function getPriceCalculationType() public view override returns (PriceCalculationType) {
        return priceCalculationType;
    }

    function getAdditionalTokensPercentage() public view override returns (uint256) {
        return additionalTokensPercentage;
    }

    function setCollectionType(CollectionType newCollectionType) public onlyRealmGuardian {

        if (newCollectionType == CollectionType.SWAP) {
            IPriceCalculator priceCalc = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(MFI_HASH)));
            require(priceCalc.exchangePairSet(), "Pair is not set in calculator");
            require(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH) != address(0), "Pancake router is not set");
        }

        collectionType = newCollectionType;

        emit CollectionTypeChanged(uint256(newCollectionType));
    }

    function setPriceCalculationType(PriceCalculationType newPriceCalculationType) public onlyRealmGuardian {
        priceCalculationType = newPriceCalculationType;

        emit PriceCalculationTypeChanged(uint256(priceCalculationType));
    }

    function setAdditionalTokensPercentage(uint256 _additionalTokensPercentage) public onlyRealmGuardian {
        additionalTokensPercentage = _additionalTokensPercentage;
    }

    function setBonusTokenPercentageFromSwap(uint256 _bonusTokenPercentageFromSwap) public onlyRealmGuardian {
        require(_bonusTokenPercentageFromSwap <= 100, "wrong bonus token percentage");
        bonusTokenPercentageFromSwap = _bonusTokenPercentageFromSwap;
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }

}