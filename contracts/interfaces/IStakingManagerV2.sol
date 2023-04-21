// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./IStakingManager.sol";

interface IStakingManagerV2 is IStakingManager {

    event StakingPaused(uint256 indexed tokenId, uint256 MFIAmount);
    event StakingResumed(uint256 indexed tokenId, uint256 MFIAmount);
    event ClaimedTokensFromAccount(uint256 indexed tokenId, uint256 MFIAmount);

    function isAccountPaused(uint256 tokenId) external view returns (bool);
    function pauseStaking(uint256 tokenId) external;
    function resumeStaking(uint256 tokenId) external;
    function claimTokensFromAccount(uint256 tokenId, uint256 numberOfTokens, address destinationAddress) external;
}