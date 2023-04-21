// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface ITreasuryAllocator {

    function setAllocatorId(uint256 id) external;
    function requestReturn() external;
    function returnAvailableTokens() external;
    function returnNumberOfTokens(uint256 amount) external;
    function getAllocationStatus() external view returns (uint256 riskFreeValue, uint256 totalValue, uint256 immediatelyClaimable);
}