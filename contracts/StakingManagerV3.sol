// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract StakingManagerV3 is IStakingManagerV3, IDestroyableContract, ContractRegistryUser {

    using SafeERC20 for IERC20;
    using SafeERC20 for IMETFI;
    using Counters for Counters.Counter;
    using Address for address payable;

    uint256 private constant INITIAL_REVERSE_METFIS_PER_FRAGMENT = ~uint160(0);

    struct StakingInfo {
        uint256 reverseMETFIs;
        uint256 level;
    }

    struct LevelSettings {
        uint256 lockedReverseMETFIs;
        uint256 reverseMETFIsPerFragment;
        uint256[] rebaseMultiplier;
    }

    LevelSettings[] public levelSettings;

    mapping(uint256 => StakingInfo) public stakingInfos;
    mapping(uint256 => uint256) public pausedMETFI;
    mapping(uint256 => bool) public pausedAccounts;

    uint256 public totalPausedMETFI;

    uint256 public lastRebase;
    uint256 public immutable rebaseTimeout = 12 hours;

    bool public inLiquidation;
    bool public dynamicDistribution;

    Counters.Counter public rebasesInHalvingCounter;
    Counters.Counter public stakingPeriod;

    uint256 public distributionsUntilNextWithdrawal;
    uint256 constant public REBASES_PER_HALVING = 365;
    uint256 public distributionsPerPeriod = 365;
    uint256 public tokensToDistributePerDistributionInPeriod;


    //----------------- Access control ------------------------------------------
    bytes32[] public allowedMETFITakingContracts;

    modifier onlyApprovedMETFITakers() {
        for (uint256 x = 0; x < allowedMETFITakingContracts.length; x++) {
            if (msg.sender == contractRegistry.getContractAddress(allowedMETFITakingContracts[x])) {
                _;
                return;
            }
        }

        revert("Not approved METFI taker");
    }

    function notInLiquidation() internal view {
        require(!inLiquidation, "StakingManager in liquidation");
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry, uint256[][] memory _rebaseMultipliers) ContractRegistryUser(_contractRegistry) {

        allowedMETFITakingContracts.push(LENDING_HASH);

        for (uint256 x = 0; x < _rebaseMultipliers.length; x++) {
            levelSettings.push(LevelSettings(0, INITIAL_REVERSE_METFIS_PER_FRAGMENT, _rebaseMultipliers[x]));
        }


        stakingInfos[1] = StakingInfo(0, 9);
        emit StakingAccountCreated(1, 9, 0);
    }

    function getAccountTokens(uint256 tokenId) public view override returns (uint256) {
        if (isAccountPaused(tokenId)) {
            return pausedMETFI[tokenId];
        } else {
            return stakingInfos[tokenId].reverseMETFIs / levelSettings[stakingInfos[tokenId].level].reverseMETFIsPerFragment;
        }
    }

    function isAccountPaused(uint256 tokenId) public view override returns (bool) {
        return pausedAccounts[tokenId];
    }

    function isInDynamicStaking() external view override returns (bool) {
        return dynamicDistribution;
    }

    function rebasesUntilNextHalvingOrDistribution() external view returns (uint256) {
        if (dynamicDistribution) {
            return distributionsUntilNextWithdrawal;
        } else {
            return REBASES_PER_HALVING - (rebasesInHalvingCounter.current() % REBASES_PER_HALVING);
        }

    }

    function currentStakingMultipliersOrNewTokensPerLevelPerMETFI() external view returns (uint256[] memory) {

        if (dynamicDistribution) {
            uint256[] memory tokenMultiplierPerLevel = new uint256[](levelSettings.length);

            uint256 additionalTokens = tokensToDistributePerDistributionInPeriod;
            uint256 weightedTotal = 0;
            uint256[] memory weightedLockedMETFIPerLevel = new uint256[](levelSettings.length);

            LevelSettings memory currentLevelSettings;

            for (uint256 x = 0; x < levelSettings.length; x++) {
                currentLevelSettings = levelSettings[x];
                weightedLockedMETFIPerLevel[x] = (currentLevelSettings.lockedReverseMETFIs * (x + 1)) / currentLevelSettings.reverseMETFIsPerFragment;
                weightedTotal += weightedLockedMETFIPerLevel[x];
            }

            for (uint256 x = 0; x < levelSettings.length; x++) {
                currentLevelSettings = levelSettings[x];

                uint256 newAdditionalTokens = additionalTokens * weightedLockedMETFIPerLevel[x] / weightedTotal;
                uint256 currentTokens = currentLevelSettings.lockedReverseMETFIs / currentLevelSettings.reverseMETFIsPerFragment;
                uint256 newTokensInLevel = currentTokens + newAdditionalTokens;
                tokenMultiplierPerLevel[x] = newTokensInLevel * 10000 / currentTokens;
            }

            return tokenMultiplierPerLevel;

        } else {
            uint256[] memory multipliers = new uint256[](levelSettings.length);
            uint256 activeHalvingPeriod = rebasesInHalvingCounter.current() / REBASES_PER_HALVING;
            for (uint256 x = 0; x < levelSettings.length; x++) {
                multipliers[x] = levelSettings[x].rebaseMultiplier[activeHalvingPeriod];
            }
            return multipliers;
        }
    }

    function createStakingAccount(uint256 tokenId, uint256 numberOfTokens, uint256 level) external override {
        onlyRouter();
        notInLiquidation();

        uint256 reverseMETFIAmount = levelSettings[level].reverseMETFIsPerFragment * numberOfTokens;
        levelSettings[level].lockedReverseMETFIs += reverseMETFIAmount;
        stakingInfos[tokenId] = StakingInfo(reverseMETFIAmount, level);

        emit StakingAccountCreated(tokenId, level, numberOfTokens);
    }

    function pauseStaking(uint256 tokenId) external override {
        onlyRouter();
        notInLiquidation();

        StakingInfo memory stakingInfo = stakingInfos[tokenId];

        levelSettings[stakingInfo.level].lockedReverseMETFIs -= stakingInfo.reverseMETFIs;
        uint256 tokensInStaking = stakingInfo.reverseMETFIs / levelSettings[stakingInfo.level].reverseMETFIsPerFragment;
        stakingInfos[tokenId].reverseMETFIs = 0;

        pausedMETFI[tokenId] = tokensInStaking;
        totalPausedMETFI += tokensInStaking;
        pausedAccounts[tokenId] = true;

        emit StakingPaused(tokenId, tokensInStaking);
    }

    function resumeStaking(uint256 tokenId) external override {
        onlyRouter();
        notInLiquidation();

        uint256 numberOfTokens = pausedMETFI[tokenId];
        pausedMETFI[tokenId] = 0;
        totalPausedMETFI -= numberOfTokens;

        uint256 additionalReverseMETFIs = levelSettings[stakingInfos[tokenId].level].reverseMETFIsPerFragment * numberOfTokens;
        levelSettings[stakingInfos[tokenId].level].lockedReverseMETFIs += additionalReverseMETFIs;
        stakingInfos[tokenId].reverseMETFIs += additionalReverseMETFIs;

        pausedAccounts[tokenId] = false;

        emit StakingResumed(tokenId, numberOfTokens);
    }

    function liquidateAccount(uint256 tokenId, address owner) external override {
        onlyRouter();
        notInLiquidation();

        uint256 tokensInStaking;

        if (isAccountPaused(tokenId)) {

            tokensInStaking = pausedMETFI[tokenId];
            totalPausedMETFI -= tokensInStaking;

        } else {

            StakingInfo memory stakingInfo = stakingInfos[tokenId];
            levelSettings[stakingInfo.level].lockedReverseMETFIs -= stakingInfo.reverseMETFIs;
            tokensInStaking = stakingInfo.reverseMETFIs / levelSettings[stakingInfo.level].reverseMETFIsPerFragment;

        }

        uint256 tokensToBurn = tokensInStaking / 10;
        uint256 tokensToUser = tokensInStaking - tokensToBurn;

        IERC20 METFI = IERC20(contractRegistry.getContractAddress(METFI_HASH));
        IBurnControllerV2 burnController = IBurnControllerV2(contractRegistry.getContractAddress(BURN_CONTROLLER_HASH));

        METFI.safeApprove(address(burnController), tokensToBurn);
        burnController.burnWithTransfer(tokensToBurn);

        delete stakingInfos[tokenId];
        delete pausedMETFI[tokenId];
        delete pausedAccounts[tokenId];

        METFI.safeTransfer(owner, tokensToUser);

        emit StakingAccountLiquidated(tokenId, tokensToUser);
    }

    function addTokensToStaking(uint256 tokenId, uint256 numberOfTokens) external override {
        onlyRouter();
        notInLiquidation();

        if (isAccountPaused(tokenId)) {
            pausedMETFI[tokenId] += numberOfTokens;
            totalPausedMETFI += numberOfTokens;
        } else {
            uint256 additionalReverseMETFIs = levelSettings[stakingInfos[tokenId].level].reverseMETFIsPerFragment * numberOfTokens;
            levelSettings[stakingInfos[tokenId].level].lockedReverseMETFIs += additionalReverseMETFIs;
            stakingInfos[tokenId].reverseMETFIs += additionalReverseMETFIs;
        }

        emit TokensAddedToStaking(tokenId, numberOfTokens);
    }

    function upgradeStakingAccountToLevel(uint256 tokenId, uint256 newLevel) external override {
        onlyRouter();
        notInLiquidation();

        if (!isAccountPaused(tokenId)) {
            uint256 currentLevel = stakingInfos[tokenId].level;
            levelSettings[currentLevel].lockedReverseMETFIs -= stakingInfos[tokenId].reverseMETFIs;
            stakingInfos[tokenId].reverseMETFIs = stakingInfos[tokenId].reverseMETFIs / levelSettings[currentLevel].reverseMETFIsPerFragment * levelSettings[newLevel].reverseMETFIsPerFragment;
            levelSettings[newLevel].lockedReverseMETFIs += stakingInfos[tokenId].reverseMETFIs;
        }

        stakingInfos[tokenId].level = newLevel;

        emit StakingAccountUpgraded(tokenId, newLevel, getAccountTokens(tokenId));
    }

    function claimTokensFromAccount(uint256 tokenId, uint256 numberOfTokens, address destinationAddress) external onlyApprovedMETFITakers override {
        notInLiquidation();
        if (isAccountPaused(tokenId)) {

            require(numberOfTokens <= pausedMETFI[tokenId], "Insufficient METFI");

            pausedMETFI[tokenId] -= numberOfTokens;
            totalPausedMETFI -= numberOfTokens;

        } else {

            uint256 reverseMETFIsToRemove = levelSettings[stakingInfos[tokenId].level].reverseMETFIsPerFragment * numberOfTokens;
            require(reverseMETFIsToRemove <= stakingInfos[tokenId].reverseMETFIs, "Insufficient METFI");

            levelSettings[stakingInfos[tokenId].level].lockedReverseMETFIs -= reverseMETFIsToRemove;
            stakingInfos[tokenId].reverseMETFIs -= reverseMETFIsToRemove;
        }

        getMETFI().safeTransfer(destinationAddress, numberOfTokens);

        emit ClaimedTokensFromAccount(tokenId, numberOfTokens);
    }

    function timeToNextRebase() external view override returns (uint256) {

        if ((block.timestamp - lastRebase) < rebaseTimeout) {
            return rebaseTimeout - (block.timestamp - lastRebase);
        }

        return 0;
    }

    function nextRebaseAt() external view override returns (uint256) {
        return lastRebase + rebaseTimeout;
    }

    function rebase() external override {
        notInLiquidation();

        if ((block.timestamp - lastRebase) < rebaseTimeout) {
            return;
        }

        lastRebase = block.timestamp;

        uint256 additionalTokens = 0;

        uint256 oldTokenNum;
        uint256 newTokenNum;
        LevelSettings memory currentLevelSettings;

        if (dynamicDistribution) {

            additionalTokens = tokensToDistributePerDistributionInPeriod;
            uint256 weightedTotal = 0;
            uint256[] memory weightedLockedMETFIPerLevel = new uint256[](levelSettings.length);

            for (uint256 x = 0; x < levelSettings.length; x++) {
                currentLevelSettings = levelSettings[x];
                weightedLockedMETFIPerLevel[x] = (currentLevelSettings.lockedReverseMETFIs * (x + 1)) / currentLevelSettings.reverseMETFIsPerFragment;
                weightedTotal += weightedLockedMETFIPerLevel[x];
            }

            for (uint256 x = 0; x < levelSettings.length; x++) {

                currentLevelSettings = levelSettings[x];
                uint256 newAdditionalTokens = additionalTokens * weightedLockedMETFIPerLevel[x] / weightedTotal;
                uint256 currentTokens = currentLevelSettings.lockedReverseMETFIs / currentLevelSettings.reverseMETFIsPerFragment;
                newTokenNum = currentTokens + newAdditionalTokens;
                levelSettings[x].reverseMETFIsPerFragment = currentLevelSettings.lockedReverseMETFIs / newTokenNum;

                emit StakingLevelRebased(x, newTokenNum);

            }

            distributionsUntilNextWithdrawal--;

            if (distributionsUntilNextWithdrawal == 0) {
                startNextStakingPeriod();
            }

        } else {

            uint256 activeHalvingPeriod = rebasesInHalvingCounter.current() / REBASES_PER_HALVING;

            if (rebasesInHalvingCounter.current() % REBASES_PER_HALVING == 0) {
                stakingPeriod.increment();
            }

            for (uint256 x = 0; x < levelSettings.length; x++) {
                currentLevelSettings = levelSettings[x];
                oldTokenNum = currentLevelSettings.lockedReverseMETFIs / currentLevelSettings.reverseMETFIsPerFragment;
                levelSettings[x].reverseMETFIsPerFragment = currentLevelSettings.reverseMETFIsPerFragment * levelSettings[x].rebaseMultiplier[activeHalvingPeriod] / 1000000000;
                newTokenNum = (currentLevelSettings.lockedReverseMETFIs / levelSettings[x].reverseMETFIsPerFragment);
                additionalTokens += newTokenNum - oldTokenNum;

                emit StakingLevelRebased(x, newTokenNum);

            }

            rebasesInHalvingCounter.increment();

            IMETFIStakingPool(contractRegistry.getContractAddress(METFI_STAKING_POOL_HASH)).withdrawMETFI(address(this), additionalTokens);

            if (rebasesInHalvingCounter.current() == (6 * 365)) {
                dynamicDistribution = true;
                startNextStakingPeriod();
            }

        }

        emit StakingRebased(additionalTokens);
    }

    function setStakingPeriodLength(uint256 distributions, bool restartExisting) external {
        onlyRealmGuardian();
        uint256 oldDistributionsPerPeriod = distributionsPerPeriod;
        distributionsPerPeriod = distributions;

        if (restartExisting) {
            IERC20(contractRegistry.getContractAddress(METFI_HASH)).safeTransfer(contractRegistry.getContractAddress(METFI_STAKING_POOL_HASH), distributionsUntilNextWithdrawal * tokensToDistributePerDistributionInPeriod);
            startNextStakingPeriod();
        }

        emit StakingPeriodLengthChanged(oldDistributionsPerPeriod, distributions);
    }

    function startNextStakingPeriod() internal {
        stakingPeriod.increment();
        uint256 receivedMETFI = IMETFIStakingPool(contractRegistry.getContractAddress(METFI_STAKING_POOL_HASH)).withdrawMETFIForNextStakingPeriod();
        distributionsUntilNextWithdrawal = distributionsPerPeriod;
        tokensToDistributePerDistributionInPeriod = receivedMETFI / distributionsPerPeriod;
    }


    function totalLevels() external view returns (uint256) {
        return levelSettings.length;
    }

    function addAllowedMETFITakingContract(string calldata name) external {
        onlyRealmGuardian();

        allowedMETFITakingContracts.push(keccak256(abi.encodePacked(name)));

        emit AddedAllowedMETFITakingContract(name);
    }

    function removeAllowedMETFITakingContract(string calldata name) external {
        onlyRealmGuardian();

        bytes32 nameHash = keccak256(abi.encodePacked(name));

        for (uint256 i = 0; i < allowedMETFITakingContracts.length; i++) {
            if (allowedMETFITakingContracts[i] == nameHash) {
                allowedMETFITakingContracts[i] = allowedMETFITakingContracts[allowedMETFITakingContracts.length - 1];
                allowedMETFITakingContracts.pop();
                break;
            }
        }

        emit RemovedAllowedMETFITakingContract(name);
    }

    function enterLiquidation() external override returns (uint256 totalMETFIStaked) {
        onlyTreasury();
        notInLiquidation();

        IERC20 token = IERC20(contractRegistry.getContractAddress(METFI_HASH));

        totalMETFIStaked = token.balanceOf(address(this));

        inLiquidation = true;
        token.safeTransfer(msg.sender, totalMETFIStaked);
    }

    function destroyContract(address payable to) external override {
        onlyTreasury();

        to.sendValue(address(this).balance);
    }

    /**
    @notice Gets lost tokens, that have been sent to this contract by mistake.
    @param tokenAddress The address of the token to withdraw.
    */
    function getLostTokens(address tokenAddress) public virtual override {

        if (contractRegistry.getContractAddress(METFI_HASH) == tokenAddress) {
            revert METFINotWithdrawable();
        }

        super.getLostTokens(tokenAddress);

    }
}