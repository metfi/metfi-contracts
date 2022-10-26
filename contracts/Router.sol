// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IAccountToken.sol";
import "./interfaces/IRewardDistributor.sol";
import "./interfaces/ITokenCollector.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";

contract Router is IRouter, ILostTokenProvider, IDestroyableContract {

    using SafeERC20 for IERC20;

    uint256[] levelPricesInBUSD;

    IERC20 public busd;

    //----------------- Access control -------------------------------------------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));
    bytes32 constant TOKEN_COLLECTOR_HASH = keccak256(abi.encodePacked('token_collector'));
    bytes32 constant REWARD_DISTRIBUTOR_HASH = keccak256(abi.encodePacked('reward_distributor'));
    bytes32 constant ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));

    modifier verifySenderAndNFT(uint256 nftId) {
        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        require(accountTokens.ownerOf(nftId) == msg.sender, "You don't own this token");
        require(!accountTokens.accountLiquidated(nftId), "Account liquidated");
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "not EOA");
        _;
    }
    //----------------------------------------------------------------------------------------------------------------

    constructor(
        IContractRegistry _contractRegistry,
        IERC20 _busd,
        uint256[] memory _levelPricesInUSD
    ) {

        require(_levelPricesInUSD.length == 10, "wrong _levelPricesInUSD length");

        contractRegistry = _contractRegistry;
        busd = _busd;

        uint256 busdMultiplier = 10 ** 18;

        for(uint256 x = 0; x < _levelPricesInUSD.length; x++) {
            levelPricesInBUSD.push(_levelPricesInUSD[x] * busdMultiplier);
        }
    }

    //Account management ----------------
    function createAccount(address newOwner, uint256 level, uint256 minTokensOut, string calldata newReferralLink, uint256 additionalTokensValue) public onlyEOA override returns (uint256) {

        return _createAccount(newOwner, 1, level, minTokensOut, newReferralLink, additionalTokensValue);
    }

    function createAccountWithReferral(address newOwner, string calldata referralId, uint256 level, uint256 minTokensOut, string calldata newReferralLink, uint256 additionalTokensValue) public onlyEOA override returns (uint256) {

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        uint256 parentId = accountTokens.getAccountByReferral(referralId);
        return _createAccount(newOwner, parentId, level, minTokensOut, newReferralLink, additionalTokensValue);
    }

    function _createAccount(address newOwner, uint256 parentId, uint256 level, uint256 minTokensOut, string calldata newReferralLink, uint256 additionalTokensValue) internal returns (uint256) {

        rebaseStaking();
        IRewardDistributor rewardDistributor = IRewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));

        require(level < levelPricesInBUSD.length, "Level does not exist");

        (, uint256 totalActiveNFTs) = accountTokens.getAddressNFTs(newOwner);
        require(totalActiveNFTs == 0, 'This user already owns position');

        //Mint new token
        uint256 newTokenID = accountTokens.createAccount(newOwner, parentId, level, newReferralLink);
        rewardDistributor.createAccount(newTokenID, parentId);

        uint256 freeMFITokensReceived = handleLevelCreationAndUpgrades(newTokenID, 0, level, additionalTokensValue, minTokensOut);

        emit AccountCreated(newTokenID, parentId, level, additionalTokensValue, newReferralLink, freeMFITokensReceived);

        return newTokenID;
    }

    function upgradeNFTToLevel(uint256 nftId, uint256 minTokensOut, uint256 finalLevel, uint256 additionalTokensValue) public onlyEOA verifySenderAndNFT(nftId) override {

        rebaseStaking();

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));

        require(finalLevel < levelPricesInBUSD.length, "Level does not exist");

        uint256 currentLevel = accountTokens.getAccountLevel(nftId);

        require(finalLevel > currentLevel, "Next level needs to be bigger than current level");

        accountTokens.upgradeAccountToLevel(nftId, finalLevel);

        uint256 freeMFITokensReceived = handleLevelCreationAndUpgrades(nftId, currentLevel + 1, finalLevel, additionalTokensValue, minTokensOut);

        emit AccountUpgraded(nftId, finalLevel, additionalTokensValue, freeMFITokensReceived);
    }

    function handleLevelCreationAndUpgrades(uint256 nftId, uint256 initialLevel, uint256 finalLevel, uint256 additionalTokensValue, uint256 minTokensOut) internal returns (uint256 freeMFITokensReceived) {

        IRewardDistributor rewardDistributor = IRewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));

        uint256 levelsPrice = 0;

        for (uint256 nextLevel = initialLevel; nextLevel <= finalLevel; nextLevel++) {
            levelsPrice += levelPricesInBUSD[nextLevel];
        }

        busd.safeTransferFrom(msg.sender, contractRegistry.getContractAddress(TREASURY_HASH), levelsPrice + additionalTokensValue);

        for (uint256 nextLevel = initialLevel; nextLevel <= finalLevel; nextLevel++) {

            {
                (uint256 nextMatrixParentId, uint256[] memory accountsOvertaken) = accountTokens.getLevelMatrixParent(nftId, nextLevel);
                contractRegistry.getMatrix(nextLevel).addNode(nftId, nextMatrixParentId);

                for (uint256 x = 0; x < accountsOvertaken.length; x++) {
                    emit AccountOvertaken(accountsOvertaken[x], nftId, nextLevel);
                }
            }

            rewardDistributor.accountUpgraded(nftId, nextLevel);
            rewardDistributor.distributeRewards(levelPricesInBUSD[nextLevel], 0, nftId, nextLevel);
        }

        //Add required number of tokens directly into the staking manager
        ITokenCollector tokenCollector = ITokenCollector(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH));
        uint256 totalTokens = tokenCollector.getBonusTokens(levelsPrice / 10);
        freeMFITokensReceived = totalTokens;

        if (additionalTokensValue > 0) {

            //Emit TokensBought event when adding tokens at upgrade
            uint256 tokensBought = tokenCollector.getTokens(additionalTokensValue, minTokensOut);
            totalTokens += tokensBought;

            rewardDistributor.distributeRewards(additionalTokensValue, 1, nftId, finalLevel);
            emit TokensBought(nftId, additionalTokensValue, tokensBought, finalLevel);
        }

        IStakingManager stakingManager = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
        if(initialLevel == 0) {
            stakingManager.createStakingAccount(nftId, totalTokens, finalLevel);
        }else {
            stakingManager.upgradeStakingAccountToLevel(nftId, finalLevel);
            stakingManager.addTokensToStaking(nftId, totalTokens);
        }

        return freeMFITokensReceived;
    }

    function setReferralLink(uint256 nftId, string calldata newReferralLink) public verifySenderAndNFT(nftId) override {

        rebaseStaking();

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        accountTokens.setReferralLink(nftId, newReferralLink);
    }

    function liquidateAccount(uint256 nftId) public verifySenderAndNFT(nftId) override {

        rebaseStaking();

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));

        bool liquidated = accountTokens.requestLiquidation(nftId);
        if(liquidated) {

            IRewardDistributor rewardDistributor = IRewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
            IStakingManager stakingManager = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));

            rewardDistributor.liquidateAccount(nftId);
            stakingManager.liquidateAccount(nftId, msg.sender);

            emit AccountLiquidated(nftId);
        }else {
            emit AccountLiquidationStarted(nftId);
        }
    }

    function cancelLiquidation(uint256 nftId) public verifySenderAndNFT(nftId) override {

        rebaseStaking();

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        accountTokens.cancelLiquidation(nftId);

        emit AccountLiquidationCanceled(nftId);
    }

    //-------------------------

    //Staking
    function stakeTokens(uint256 nftId, uint256 numberOfTokens) public verifySenderAndNFT(nftId) override {

        rebaseStaking();

        //Add tokens to existing staking account
        IStakingManager stakingManager = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
        stakingManager.addTokensToStaking(nftId, numberOfTokens);

        //Transfer MFI from user to staking manager
        IERC20(contractRegistry.getContractAddress(MFI_HASH)).safeTransferFrom(msg.sender, address(stakingManager), numberOfTokens);

        emit TokensStaked(nftId, numberOfTokens);
    }
    //-------------------------

    //Bonding
    function buyTokens(uint256 nftId, uint256 busdPrice, uint256 minTokensOut) public onlyEOA verifySenderAndNFT(nftId) override {

        rebaseStaking();

        IAccountToken accountTokens = IAccountToken(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        IStakingManager stakingManager = IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH));
        IRewardDistributor rewardDistributor = IRewardDistributor(contractRegistry.getContractAddress(REWARD_DISTRIBUTOR_HASH));
        ITokenCollector tokenCollector = ITokenCollector(contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH));

        uint256 currentLevel = accountTokens.getAccountLevel(nftId);

        //Transfer payment from user to treasury
        busd.safeTransferFrom(msg.sender, contractRegistry.getContractAddress(TREASURY_HASH), busdPrice);

        uint256 numberOfTokens = tokenCollector.getTokens(busdPrice, minTokensOut);

        //Add tokens to existing staking account
        stakingManager.addTokensToStaking(nftId, numberOfTokens);

        //Distribute token buying rewards
        rewardDistributor.distributeRewards(busdPrice, 1, nftId, currentLevel);

        emit TokensBought(nftId, busdPrice, numberOfTokens, currentLevel);
    }
    //-------------------------


    function totalLevels() public view returns (uint256) {
        return levelPricesInBUSD.length;
    }

    function rebaseStaking() public {
        IStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH)).rebase();
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }
}