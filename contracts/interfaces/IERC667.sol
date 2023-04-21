// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC677 is IERC20 {
    function transferAndCall(
        address to,
        uint value,
        bytes memory data
    )
    external
    returns (bool success);

    event Transfer(
        address indexed from,
        address indexed to,
        uint value,
        bytes data
    );
}