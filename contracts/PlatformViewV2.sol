// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract PlatformViewV2 is IPlatformViewV2, ContractRegistryUser {

    using SafeERC20 for IERC20;

    uint256 constant public numberOfLevels = 10;

    constructor(
        IContractRegistry _contractRegistry
    ) ContractRegistryUser(_contractRegistry) {}

    function getNFTData(uint256 nftId) public view override returns (NFTData memory NFT) {

        IRewardDistributor rewardDistributor = getRewardDistributor();
        IAccountToken accountTokens = getAccountToken();
        IUserConfig userConfig = getUserConfig();

        NFT.ID = nftId;
        NFT.readOnly = false;
        NFT.level = accountTokens.getAccountLevel(nftId);
        NFT.referralLink = accountTokens.getAccountReferralLink(nftId);
        NFT.directUplink = accountTokens.getDirectUplink(nftId);
        NFT.stakedTokens = stakedTokens(nftId);
        NFT.rewardingInfo = rewardDistributor.getAccountInfo(nftId);
        NFT.directlyEnrolledMembers = accountTokens.getAccountDirectlyEnrolledMembers(nftId);
        NFT.userConfigValues = userConfig.getAllUserConfigValues(nftId);

        IAccountToken.LiquidationInfo memory liquidationInfo = accountTokens.getLiquidationInfo(nftId);
        NFT.liquidationRequestTime = liquidationInfo.requestTime;
        NFT.liquidationAvailableTime = liquidationInfo.availableTime;
        NFT.liquidationExpiredTime = liquidationInfo.expirationTime;
        NFT.liquidated = accountTokens.accountLiquidated(nftId);
        NFT.stakingPaused = stakingPaused(nftId);

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

    function getWalletData(address wallet) external view override returns (NFTData[] memory NFTs) {

        IAccountToken accountTokens = getAccountToken();

        (uint256[] memory activeNFTs, uint256 numberOfTokens) = accountTokens.getAddressNFTs(wallet);
        uint256[] memory NFTsInLoans = getAddressActiveLoanNFTs(wallet);

        NFTs = new NFTData[](numberOfTokens + NFTsInLoans.length);
        uint256 n = 0;
        for (; n < numberOfTokens; n++) {
            NFTs[n] = getNFTData(activeNFTs[n]);
        }

        for (uint256 x = 0; x < NFTsInLoans.length; x++) {
            NFTs[n] = getNFTData(NFTsInLoans[x]);
            NFTs[n].readOnly = true;
            n++;
        }

        return NFTs;
    }

    function getAddressActiveLoanNFTs(address borrower) public view override returns (uint256[] memory) {

        ILendingPlatformView lending = getLendingPlatformView();

        uint256 activeLoans = 0;

        for(uint256 i = 0; true; i++) {
            try lending.borrowersLoans(borrower, i) returns (uint256 currentLoanId) {
                ILendingStructs.LoanInfo memory currentLoan = lending.getLoanById(currentLoanId);
                if (currentLoan.stage == ILendingStructs.LoanStage.Funded) {
                    activeLoans++;
                }
            } catch {
                break;
            }
        }

        uint256[] memory activeNFTs = new uint256[](activeLoans);
        uint256 activeIndex = 0;
        for(uint256 i = 0; true; i++) {
            try lending.borrowersLoans(borrower, i) returns (uint256 currentLoanId) {
                ILendingStructs.LoanInfo memory currentLoan = lending.getLoanById(currentLoanId);
                if (currentLoan.stage == ILendingStructs.LoanStage.Funded) {
                    activeNFTs[activeIndex] = currentLoan.tokenId;
                    activeIndex++;
                }
            } catch {
                break;
            }
        }

        return activeNFTs;
    }

    function getReferralCodeData(string calldata referralCode) external view override returns (NFTData memory) {
        return getNFTData(getAccountToken().getAccountByReferral(referralCode));
    }

    function referralLinkExists(string calldata referralCode) external view override returns (bool) {
        return getAccountToken().referralLinkExists(referralCode);
    }

    function getMETFIPrice() external view override returns (uint256){
        return getPriceCalculator(contractRegistry.getContractAddress(METFI_HASH)).getPriceInUSD();
    }

    function getPlatformData() external view override returns (PlatformData memory data) {

        ITreasuryV2 treasury = getTreasury();
        IPriceCalculator priceCalculator = getPriceCalculator(contractRegistry.getContractAddress(METFI_HASH));
        ITokenCollectorV2 tokenCollector = getTokenCollector();
        IAccountToken accountTokens = getAccountToken();
        IStakingManagerV3 stakingManager = getStakingManager();

        data.METFIPrice = priceCalculator.getPriceInUSD();
        data.totalMembers = accountTokens.totalMembers();
        data.averageAPY = accountTokens.getAverageAPY();
        (data.treasuryValue, data.treasuryRiskFreeValue) = treasury.getValue();
        data.stakedTokens = getMETFIERC20().balanceOf(address(stakingManager));
        data.tokenCollectionType = tokenCollector.getCollectionType();
        data.priceCalculationType = tokenCollector.getPriceCalculationType();
        data.tokenCollectionPercentage = tokenCollector.getAdditionalTokensPercentage();
        data.totalRewardsPaid = treasury.getTotalRewardsPaid();
        data.dynamicStaking = stakingManager.isInDynamicStaking();
        data.currentStakingMultipliers = stakingManager.currentStakingMultipliersOrNewTokensPerLevelPerMETFI();
        data.rebasesUntilNextHalvingOrDistribution = stakingManager.rebasesUntilNextHalvingOrDistribution();

        if (data.stakedTokens > 0) {
            data.valuePerToken = data.treasuryValue / data.stakedTokens;
            data.backingPerToken = data.treasuryRiskFreeValue / data.stakedTokens;
        }

        data.nextRebaseAt = stakingManager.nextRebaseAt();

        (data.metfiLiquidityReserve, data.stableCoinLiquidityReserve) = priceCalculator.getReserves();

        return data;
    }

    function getTreeData(uint256 nftId, uint256 matrixLevel, uint256 toDepthLevel) external view override returns (TreeNodeData memory selectedNFT, TreeNodeData[] memory subNFTs) {


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
        return getStakingManager().getAccountTokens(nftId);
    }

    function stakingPaused(uint256 nftId) public view override returns (bool) {
        return getStakingManager().isAccountPaused(nftId);
    }

    function stakedTokensForAddress(address wallet) external view override returns (uint256) {

        uint256 totalTokens = 0;

        IAccountToken accountTokens = getAccountToken();
        uint256 numberOfTokens = accountTokens.balanceOf(wallet);

        for (uint256 x = 0; x < numberOfTokens; x++) {
            totalTokens += stakedTokens(accountTokens.tokenOfOwnerByIndex(wallet, x));
        }

        return totalTokens;
    }

}