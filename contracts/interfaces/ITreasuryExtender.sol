// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITreasuryExtender {

    event AllocatorAdded(address indexed allocator, address indexed approvedToken, uint256 allocatorId, uint256 approvalAmount, uint256 allowanceIncreaseOnReturnPercentage);
    event AllocatorFundsClaimed(uint256 indexed allocatorId, uint256 amount);
    event AllocatorFundsReturned(uint256 indexed allocatorId, uint256 amount);
    event RequestedFundsFromAllocator(uint256 indexed allocatorId);
    event ChangedAllocatorApprovalAmount(uint256 indexed allocatorId, uint256 approvalAmount, bool automatic);
    event ChangedAllocatorStatus(uint256 indexed allocatorId, bool indexed enabled);
    event ChangedAllocatorAllowanceIncreaseOnReturnPercentage(uint256 indexed allocatorId, uint256 allowanceIncreaseOnReturnPercentage);

    function getValue() external view returns (uint256 riskFreeValue, uint256 totalValue);

}
