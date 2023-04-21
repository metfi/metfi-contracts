// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending contract
// @author MetFi
// @notice This contract is responsible for managing loans
interface ILendingPlatformView is ILendingStructs {

    function borrowersLoans(address borrower, uint256 index) external view returns (uint256);

    function getLoanById(
        uint256 loanId
    ) external view returns (LoanInfo memory);
}
