// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAccountToken {
    function getAddressNFTs(address userAddress) external view returns (uint256[] memory NFTs, uint256 numberOfActive);
    function getAccountLevel(uint256 tokenId) external view returns (uint256);
}

interface IStakingManager {
    function getAccountTokens(uint256 tokenId) external view returns(uint256);
}

contract MetFiVoteCalculator {

    using SafeERC20 for IERC20;

    //MetFI contract registry with hash for mfi, staking manager and account_token access
    IContractRegistry contractRegistry;
    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));
    bytes32 constant ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));

    /**
    @notice Constructor for contract
    @param _contractRegistry for MetFi system
    */
    constructor(IContractRegistry _contractRegistry) {
        contractRegistry = _contractRegistry;
    }

    /**
    @notice Returns amount of votes that specific wallet address has
    @param voterAddress wallet address to get votes for
    */
    function availableVotes(address voterAddress) public view returns (uint256) {

        uint256 totalVotes = IERC20(contractRegistry.getContractAddress(MFI_HASH)).balanceOf(voterAddress) / 10;
        (uint256[] memory activeNFTs, uint256 numberOfNFTs) = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).getAddressNFTs(voterAddress);

        for(uint256 x = 0; x < numberOfNFTs; x++) {
            totalVotes += availableVotesForNFT(activeNFTs[x]);
        }

        return totalVotes;
    }

    /**
    @notice Returns amount of votes that specific NFT has
    @param nftId ID of NFT to get votes for
    */
    function availableVotesForNFT(uint256 nftId) public view returns (uint256) {

        uint256 accountLevel = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).getAccountLevel(nftId);
        uint256 stakedTokens = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH)).getAccountTokens(nftId);

        uint256 bonusVotes = stakedTokens * (accountLevel + 1) / 10;

        return stakedTokens + bonusVotes;
    }
}