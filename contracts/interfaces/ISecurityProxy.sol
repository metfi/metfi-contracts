// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface ISecurityProxy {
    function validateTransfer(address from, address to, uint256 amount) external view returns (bool);
}