// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface IMETFIStakingPool {

    event METFIWithdrawn(address indexed user, uint256 amount);
    event METFIWithdrawnForNextStakingPeriod(address indexed user, uint256 amount);
    event METFIPercentageForPeriodChanged(uint256 percentage);
    event METFIBurnedFromPool(uint256 amount);
    event METFIStakingPoolMigrated(address indexed to, uint256 amount);

    function withdrawMETFI(address to, uint256 METFIAmount) external;
    function withdrawMETFIForNextStakingPeriod() external returns (uint256 amount);

}