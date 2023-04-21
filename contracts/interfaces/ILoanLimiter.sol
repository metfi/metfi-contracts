// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending Limiter contract
// @author MetFi
// @notice This contract is responsible for limiting loans
interface ILoanLimiter is ILendingStructs{
    function canLoanBeCreated(CreateLoanRequest memory loanRequest) external view returns (bool);

    function onLoanCreated(uint256 loanId, CreateLoanRequest memory loanRequest) external;

    function onLoanFunded(uint256 loanId, uint256 fundedAmount) external;

    function onLoanRepaid(uint256 loanId, uint256 repaidAmount) external;

    function onLoanExtended(uint256 loanId, ExtendLoanRequest memory extendLoanRequest) external;

    function onLoanLiquidated(uint256 loanId) external;

    function onLoanInvalidated(uint256 loanId) external;


}