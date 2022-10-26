// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IManageableTreasury {

    function manage(address to, address token, uint256 amount) external;

}