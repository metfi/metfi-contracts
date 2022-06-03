// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20TreasuryFundsLock {

    using SafeERC20 for IERC20;

    //MetFI contract registry with hash for treasury access
    IContractRegistry contractRegistry;
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    //Time at which the funds will unlock for transfer to treasury in unix timestamp format
    //Value is set at contract creation in constructor
    uint256 public unlockTime = 0;

    /**
    @notice Constructor for contract
    @param _contractRegistry for MetFi system
    @param lockedTime time in seconds after deployment that the funds will be unlocked
    */
    constructor(IContractRegistry _contractRegistry, uint256 lockedTime) {
        contractRegistry = _contractRegistry;
        unlockTime = block.timestamp + lockedTime;
    }

    /**
    @notice Transfer all funds at tokenAddress directly to currently deployed treasury
    @param tokenAddress address of ERC20 token to transfer to treasury
    */
    function returnFundsToTreasury(address tokenAddress) public {

        IERC20 tokenToTransfer = IERC20(tokenAddress);

        require(block.timestamp > unlockTime, "Funds are still locked");
        require(tokenToTransfer.balanceOf(address(this)) > 0, "Contract holds none of this tokens");

        tokenToTransfer.transfer(contractRegistry.getContractAddress(TREASURY_HASH), tokenToTransfer.balanceOf(address(this)));
    }
}