// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface ILostTokenProvider {
    function getLostTokens(address tokenAddress) external;
}
