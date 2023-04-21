// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface IBurnControllerV2 {

    function burnExisting() external;
    function burnWithTransfer(uint256 amount) external;
}