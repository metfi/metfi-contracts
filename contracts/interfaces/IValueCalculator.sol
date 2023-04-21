// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface IValueCalculator {
    function calculateValue() external view returns (uint256, uint256);
}