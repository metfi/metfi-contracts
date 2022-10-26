// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IUnstakedNFTMinter {

    function mintUnstakedTokens(address to, string[] memory URLs) external;
}