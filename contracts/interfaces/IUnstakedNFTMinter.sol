// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IUnstakedNFTMinter {

    function mintUnstakedTokens(address to, string[] memory URLs) external;
}