// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/ITreasuryExtender.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IDestroyableContract.sol";

contract EmptyTreasuryExtender is ITreasuryExtender, ILostTokenProvider, IDestroyableContract {

    using SafeERC20 for IERC20;

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry) {
        contractRegistry = _contractRegistry;
    }

    function getValue() public pure override returns (uint256 riskFreeValue, uint256 totalValue) {
        return (0, 0);
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function destroyContract(address payable claimEthTo) public override onlyTreasury {
        selfdestruct(claimEthTo);
    }
}