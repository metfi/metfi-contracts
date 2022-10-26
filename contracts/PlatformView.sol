// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPlatformView.sol";
import "./interfaces/IAccountToken.sol";
import "./interfaces/IPriceCalculator.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";

contract PlatformView is IPlatformView, ILostTokenProvider, IDestroyableContract {

    using SafeERC20 for IERC20;

    IContractRegistry contractRegistry;

    uint256 numberOfLevels = 10;

    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));
    bytes32 constant TOKEN_COLLECTOR_HASH = keccak256(abi.encodePacked('token_collector'));
    bytes32 constant REWARD_DISTRIBUTOR_HASH = keccak256(abi.encodePacked('reward_distributor'));
    bytes32 constant ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }

    constructor(
        IContractRegistry _contractRegistry
    ) {
        contractRegistry = _contractRegistry;
    }

    function getNFTData(uint256 nftId) public view override returns (NFTData memory NFT) {

        IRewardDistributor rewardDistributor = IRewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));

        NFT.ID = nftId;
        NFT.level = accountTokens.getAccountLevel(nftId);
        NFT.referralLink = accountTokens.getAccountReferralLink(nftId);
        NFT.directUplink = accountTokens.getDirectUplink(nftId);
        NFT.stakedTokens = stakedTokens(nftId);
        NFT.rewardingInfo = rewardDistributor.getAccountInfo(nftId);
        NFT.directlyEnrolledMembers = accountTokens.getAccountDirectlyEnrolledMembers(nftId);

        IAccountToken.LiquidationInfo memory liquidationInfo = accountTokens.getLiquidationInfo(nftId);
        NFT.liquidationRequestTime = liquidationInfo.requestTime;
        NFT.liquidationAvailableTime = liquidationInfo.availableTime;
        NFT.liquidationExpiredTime = liquidationInfo.expirationTime;
        NFT.liquidated = accountTokens.accountLiquidated(nftId);

        if (NFT.liquidated) {
            NFT.referralLink = "LIQUIDATED TOKEN";
        }

        NFT.usersInLevel = new uint256[][](numberOfLevels);
        NFT.totalUsersInMatrix = new uint256[](numberOfLevels);

        for (uint256 x; x < NFT.level + 1; x++) {
            NFT.usersInLevel[x] = new uint256[](10);
        }

        for (uint256 x = 0; x < NFT.level + 1; x++) {
            (NFT.usersInLevel[x], NFT.totalUsersInMatrix[x]) = getUsersInLevels(nftId, x);
        }

        return NFT;
    }

    function getWalletData(address wallet) public view override returns (NFTData[] memory NFTs) {

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        (uint256[] memory activeNFTs, uint256 numberOfTokens) = accountTokens.getAddressNFTs(wallet);

        NFTs = new NFTData[](numberOfTokens);
        for (uint256 x = 0; x < numberOfTokens; x++) {
            NFTs[x] = getNFTData(activeNFTs[x]);
        }

        return NFTs;
    }

    function getReferralCodeData(string calldata referralCode) public view override returns (NFTData memory) {
        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        return getNFTData(accountTokens.getAccountByReferral(referralCode));
    }

    function referralLinkExists(string calldata referralCode) public view override returns (bool) {
        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        return accountTokens.referralLinkExists(referralCode);
    }

    function getMFIPrice() public view override returns (uint256){
        IPriceCalculator priceCalculator = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(MFI_HASH)));
        return priceCalculator.getPriceInUSD();
    }

    function getPlatformData() public view override returns (PlatformData memory data) {

        ITreasury treasury = ITreasury(contractRegistry.getContractAddress(TREASURY_HASH));
        IPriceCalculator priceCalculator = IPriceCalculator(contractRegistry.getPriceCalculator(contractRegistry.getContractAddress(MFI_HASH)));
        ITokenCollector tokenCollector = ITokenCollector(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH));
        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        IStakingManager stakingManager = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));

        data.MFIPrice = priceCalculator.getPriceInUSD();
        data.totalMembers = accountTokens.totalMembers();
        data.averageAPY = accountTokens.getAverageAPY();
        (data.treasuryValue, data.treasuryRiskFreeValue) = treasury.getValue();
        data.stakedTokens = IERC20(contractRegistry.getContractAddress(MFI_HASH)).balanceOf(address(stakingManager));
        data.tokenCollectionType = tokenCollector.getCollectionType();
        data.priceCalculationType = tokenCollector.getPriceCalculationType();
        data.tokenCollectionPercentage = tokenCollector.getAdditionalTokensPercentage();
        data.totalRewardsPaid = treasury.getTotalRewardsPaid();

        if (data.stakedTokens > 0) {
            data.valuePerToken = data.treasuryValue / data.stakedTokens;
            data.backingPerToken = data.treasuryRiskFreeValue / data.stakedTokens;
        }

        data.nextRebaseAt = stakingManager.nextRebaseAt();

        (data.mfiLiquidityReserve, data.busdLiquidityReserve) = priceCalculator.getReserves();

        return data;
    }

    function getTreeData(uint256 nftId, uint256 matrixLevel, uint256 toDepthLevel) public view override returns (TreeNodeData memory selectedNFT, TreeNodeData[] memory subNFTs) {


        selectedNFT.nftData = getNFTData(nftId);
        IMatrix.Node[] memory subNodes;

        (selectedNFT.node, subNodes) = contractRegistry.getMatrix(matrixLevel).getSubNodesToLevel(nftId, toDepthLevel);
        subNFTs = new TreeNodeData[](subNodes.length);

        for (uint256 x = 0; x < subNodes.length; x++) {
            if (subNodes[x].ID > 0) {
                subNFTs[x].nftData = getNFTData(subNodes[x].ID);
                subNFTs[x].node = subNodes[x];
            }
        }

        return (selectedNFT, subNFTs);
    }

    function getUsersInLevels(uint256 nodeId, uint256 level) public view override returns (uint256[] memory levels, uint256 totalUsers) {
        return contractRegistry.getMatrix(level).getUsersInLevels(nodeId, 10);
    }

    function stakedTokens(uint256 nftId) public view override returns (uint256) {
        IStakingManager stakingManager = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
        return stakingManager.getAccountTokens(nftId);
    }

    function stakedTokensForAddress(address wallet) public view override returns (uint256) {

        uint256 totalTokens = 0;

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        uint256 numberOfTokens = accountTokens.balanceOf(wallet);

        for (uint256 x = 0; x < numberOfTokens; x++) {
            totalTokens += stakedTokens(accountTokens.tokenOfOwnerByIndex(wallet, x));
        }

        return totalTokens;
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }
}