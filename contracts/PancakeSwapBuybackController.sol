// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBuybackController.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/IPancakeRouter02.sol";

contract PancakeSwapBuybackController is ILostTokenProvider, IDestroyableContract, IBuybackController {

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

    function buyBackMFI(address token, uint256 tokenAmount, uint256 minMFIOut) public override onlyTreasury {

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(contractRegistry.getContractAddress(PANCAKE_ROUTER_HASH));

        IERC20(token).approve(address(pancakeRouter), tokenAmount);

        address[] memory path = new address[](2);
        (path[0], path[1]) = (token, contractRegistry.getContractAddress(MFI_HASH));

        uint256[] memory amounts = pancakeRouter.swapExactTokensForTokens(
            tokenAmount,
            minMFIOut,
            path,
            msg.sender,
            block.timestamp
        );

        uint256 receivedTokens = amounts[amounts.length - 1];

        emit BoughtBackMFI(token, tokenAmount, receivedTokens);
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }
}