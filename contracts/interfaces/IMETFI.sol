// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./ILostTokenProvider.sol";

interface IMETFI is IERC20, ILostTokenProvider, IERC20Permit {

    function burn(uint256 amount) external;

}
