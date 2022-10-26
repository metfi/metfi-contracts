// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAllocationProvider {

    function getAllocatedToken(uint256 allocationId) external view returns (address);
    function getAvailableAllocation(uint256 allocatorId) external view returns (uint256);
    function getAllocatedFundsFromTreasury(uint256 allocatorId, uint256 amount) external;
    function returnAllocatedFundsToTreasury(uint256 allocatorId, uint256 amount) external;
}