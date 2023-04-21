// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./interfaces/IPriceCalculator.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/IDestroyableContract.sol";

contract PriceCalculator is IPriceCalculator, IDestroyableContract {

    address public calculatedToken;
    address public stableTokenAddress;

    IContractRegistry contractRegistry;
    bytes32 constant PANCAKE_ROUTER_HASH = keccak256(abi.encodePacked('pancake_router'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }

    constructor(IContractRegistry _contractRegistry, address _calculatedToken, address _stableTokenAddress) {
        contractRegistry = _contractRegistry;
        calculatedToken = _calculatedToken;
        stableTokenAddress = _stableTokenAddress;
    }

    function exchangePairSet() public view override returns (bool) {

        if(!contractRegistry.contractAddressExists(PANCAKE_ROUTER_HASH)) return false;

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        return factory.getPair(stableTokenAddress, calculatedToken) != address(0);
    }

    function getReserves() public override view returns (uint256 calculatedTokenReserve, uint256 reserveTokenReserve) {

        if(!contractRegistry.contractAddressExists(PANCAKE_ROUTER_HASH)) return (1, 1);

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(stableTokenAddress, calculatedToken));

        if(address(pancakePair) == address(0)) {
            return (1, 1);
        }

        address token0 = pancakePair.token0();
        (uint256 reserve0, uint256 reserve1,) = pancakePair.getReserves();
        (calculatedTokenReserve, reserveTokenReserve) = calculatedToken == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        return (calculatedTokenReserve, reserveTokenReserve);
    }

    //Can be used only for reserve tokens which are USD pegged
    function getPriceInUSD() public override view returns (uint256) {

        if(!contractRegistry.contractAddressExists(PANCAKE_ROUTER_HASH)) return 10 ** 18;

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(stableTokenAddress, calculatedToken));

        if (address(pancakePair) == address(0)) {
            return 10 ** 18;
        }

        address token0 = pancakePair.token0();
        (uint256 reserve0, uint256 reserve1,) = pancakePair.getReserves();

        uint256 calculatedTokenReserve;
        uint256 reserveTokenReserve;

        (calculatedTokenReserve, reserveTokenReserve) = calculatedToken == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        require(calculatedTokenReserve > 0 && reserveTokenReserve > 0, 'No liquidity in pool');
        uint256 numerator = reserveTokenReserve * (10 ** 18) * 10000;
        uint256 denominator = (calculatedTokenReserve - (10 ** 18)) * (9975);
        return (numerator / denominator) + 1;
    }

    function tokensForPrice(uint256 reserveTokenAmount) public override view returns (uint256) {

        if(!contractRegistry.contractAddressExists(PANCAKE_ROUTER_HASH)) return reserveTokenAmount;

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(stableTokenAddress, calculatedToken));

        if (address(pancakePair) == address(0)) {
            return reserveTokenAmount;
        }

        address token0 = pancakePair.token0();
        (uint256 reserve0, uint256 reserve1,) = pancakePair.getReserves();

        uint256 calculatedTokenReserve;
        uint256 reserveTokenReserve;

        (calculatedTokenReserve, reserveTokenReserve) = calculatedToken == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        require(calculatedTokenReserve > 0 && reserveTokenReserve > 0, 'No liquidity in pool');
        uint256 amountInWithFee = reserveTokenAmount * 9975;
        uint256 numerator = amountInWithFee * calculatedTokenReserve;
        uint256 denominator = (reserveTokenReserve * 10000) + amountInWithFee;
        return numerator / denominator;
    }

    function priceForTokens(uint256 numberOfTokens) public override view returns (uint256) {

        if(!contractRegistry.contractAddressExists(PANCAKE_ROUTER_HASH)) return numberOfTokens;

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(stableTokenAddress, calculatedToken));

        if (address(pancakePair) == address(0)) {
            return numberOfTokens;
        }

        address token0 = pancakePair.token0();
        (uint256 reserve0, uint256 reserve1,) = pancakePair.getReserves();

        uint256 calculatedTokenReserve;
        uint256 reserveTokenReserve;

        (calculatedTokenReserve, reserveTokenReserve) = calculatedToken == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        require(calculatedTokenReserve > 0 && reserveTokenReserve > 0, 'No liquidity in pool');
        uint256 amountInWithFee = numberOfTokens * 9975;
        uint256 numerator = amountInWithFee * reserveTokenReserve;
        uint256 denominator = (calculatedTokenReserve * 10000) + amountInWithFee;
        return numerator / denominator;
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }

}