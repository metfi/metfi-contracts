// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./interfaces/ILiquidityController.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IDestroyableContract.sol";

contract PancakeSwapLiquidityController is ILiquidityController, IDestroyableContract {

    using SafeERC20 for IERC20;

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant PANCAKE_ROUTER_HASH = keccak256(abi.encodePacked('pancake_router'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry) {
        contractRegistry = _contractRegistry;
    }

    function getLPTokenAddress(address tokenToUse) public view override returns (address) {

        address MFIAddress = contractRegistry.getContractAddress(MFI_HASH);
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(tokenToUse, MFIAddress));

        return address(pancakePair);
    }

    function claimableTokensFromTreasuryLPTokens(address tokenToUse) public view override returns (uint256) {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        address MFIAddress = contractRegistry.getContractAddress(MFI_HASH);

        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(tokenToUse, MFIAddress));

        if (address(pancakePair) == address(0)) {
            return 0;
        }

        address token0 = pancakePair.token0();
        (uint256 reserve0, uint256 reserve1,) = pancakePair.getReserves();
        (, uint256 tokenToUseReserve) = MFIAddress == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        return tokenToUseReserve * pancakePair.balanceOf(contractRegistry.getContractAddress(TREASURY_HASH)) / pancakePair.totalSupply();
    }

    function mfiRequiredForProvidingLiquidity(address tokenToUse, uint256 amount, uint256 MFIMin) public view override returns (uint256) {

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        address MFIAddress = contractRegistry.getContractAddress(MFI_HASH);

        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(tokenToUse, MFIAddress));

        if (address(pancakePair) == address(0)) {
            return MFIMin;
        }

        address token0 = pancakePair.token0();
        (uint256 reserve0, uint256 reserve1,) = pancakePair.getReserves();
        (uint256 mfiReserve, uint256 tokenToUseReserve) = MFIAddress == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        return ((amount * mfiReserve) / tokenToUseReserve) + 1;
    }

    function provideLiquidity(address tokenToUse, uint256 amount, uint256 MFIMin) public override onlyTreasury {

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        IERC20 MFI = IERC20(contractRegistry.getContractAddress(MFI_HASH));
        IERC20 liquidityToken = IERC20(tokenToUse);

        uint256 mfiTokens = MFI.balanceOf(address(this));

        liquidityToken.approve(address(pancakeRouter), amount);
        MFI.approve(address(pancakeRouter), mfiTokens);

        (uint256 MFIProvided, uint256 liquidityTokensProvided, uint256 newLPTokenAmount) = pancakeRouter.addLiquidity(
            address(MFI),
            tokenToUse,
            mfiTokens,
            amount,
            MFIMin,
            amount,
            msg.sender,
            block.timestamp
        );

        if (MFI.balanceOf(address(this)) > 0) {
            MFI.safeTransfer(msg.sender, MFI.balanceOf(address(this)));
        }

        if (liquidityToken.balanceOf(address(this)) > 0) {
            liquidityToken.safeTransfer(msg.sender, liquidityToken.balanceOf(address(this)));
        }

        emit LiquidityProvided(tokenToUse, MFIProvided, liquidityTokensProvided, newLPTokenAmount);
    }

    function removeLiquidity(address tokenToUse, uint256 lpTokenAmount, uint256 tokenMin) public override onlyTreasury {

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));
        address MFI = contractRegistry.getContractAddress(MFI_HASH);

        IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
        IPancakePair pancakePair = IPancakePair(factory.getPair(tokenToUse, MFI));

        if (address(pancakePair) == address(0)) {
            return;
        }

        pancakePair.approve(address(pancakeRouter), lpTokenAmount);

        (uint256 MFIRemoved, uint256 liquidityTokensRemoved) = pancakeRouter.removeLiquidity(
            MFI,
            tokenToUse,
            lpTokenAmount,
            0,
            tokenMin,
            msg.sender,
            block.timestamp
        );

        emit LiquidityRemoved(tokenToUse, lpTokenAmount, MFIRemoved, liquidityTokensRemoved);
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }
}