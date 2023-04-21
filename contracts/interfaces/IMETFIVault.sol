// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface IMETFIVault {

    event METFIWithdrawn(address indexed to, uint256 amount);

    function withdrawMETFI(address to, uint256 amount) external;
}