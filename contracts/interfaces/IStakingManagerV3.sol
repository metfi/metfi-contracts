// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./IStakingManagerV2.sol";

interface IStakingManagerV3 is IStakingManagerV2 {

    event StakingPeriodLengthChanged(uint256 oldLength, uint256 newLength);
    event AddedAllowedMETFITakingContract(string indexed takingContract);
    event RemovedAllowedMETFITakingContract(string indexed takingContract);

    function isInDynamicStaking() external view returns (bool);
    function rebasesUntilNextHalvingOrDistribution() external view returns (uint256);
    function currentStakingMultipliersOrNewTokensPerLevelPerMETFI() external view returns (uint256[] memory);
}