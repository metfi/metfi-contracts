// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./interfaces/IStakingManager.sol";
import "./interfaces/ITreasury.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";

contract StakingManager is IStakingManager, ILostTokenProvider, IDestroyableContract {

    using SafeERC20 for IERC20;

    uint256 private constant INITIAL_REVERSE_MFIS_PER_FRAGMENT = ~uint160(0);

    struct StakingInfo {
        uint256 reverseMFIs;
        uint256 level;
    }

    struct LevelSettings {
        uint256 lockedReverseMFIs;
        uint256 reverseMFIsPerFragment;
        uint256 rebaseMultiplier;
    }

    LevelSettings[] public levelSettings;

    mapping(uint256 => StakingInfo) public stakingInfos;

    uint256 lastRebase;
    uint256 rebaseTimeout;

    bool inLiquidation;

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant ROUTER_HASH = keccak256(abi.encodePacked('router'));
    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyRouter() {
        require(msg.sender == contractRegistry.getContractAddress(ROUTER_HASH));
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }

    modifier notInLiquidation() {
        require(!inLiquidation, "StakingManager in liquidation");
        _;
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry, uint256[] memory _rebaseMultipliers, uint256 _rebaseTimeout) {

        contractRegistry = _contractRegistry;
        rebaseTimeout = _rebaseTimeout;

        for(uint256 x = 0; x < _rebaseMultipliers.length; x++) {
            levelSettings.push(LevelSettings(0, INITIAL_REVERSE_MFIS_PER_FRAGMENT, _rebaseMultipliers[x]));
        }

        stakingInfos[1] = StakingInfo(levelSettings[9].reverseMFIsPerFragment * (112530 * (10 ** 18)), 9);
        levelSettings[9].lockedReverseMFIs += stakingInfos[1].reverseMFIs;
        emit StakingAccountCreated(1, 9, 112530 * (10 ** 18));
    }

    function getAccountTokens(uint256 tokenId) public view override returns(uint256) {
        return stakingInfos[tokenId].reverseMFIs / levelSettings[stakingInfos[tokenId].level].reverseMFIsPerFragment;
    }

    function createStakingAccount(uint256 tokenId, uint256 numberOfTokens, uint256 level) public onlyRouter notInLiquidation override {

        uint256 reverseMFIAmount = levelSettings[level].reverseMFIsPerFragment * numberOfTokens;
        levelSettings[level].lockedReverseMFIs += reverseMFIAmount;
        stakingInfos[tokenId] = StakingInfo(reverseMFIAmount, level);

        emit StakingAccountCreated(tokenId, level, numberOfTokens);
    }

    function liquidateAccount(uint256 tokenId, address owner) public onlyRouter notInLiquidation override {

        StakingInfo memory stakingInfo = stakingInfos[tokenId];
        levelSettings[stakingInfo.level].lockedReverseMFIs -= stakingInfo.reverseMFIs;
        uint256 tokensInStaking = stakingInfo.reverseMFIs / levelSettings[stakingInfo.level].reverseMFIsPerFragment;

        uint256 tokensToDAO = tokensInStaking / 10;
        uint256 tokensToUser = tokensInStaking - tokensToDAO;

        uint256 additionalReverseMFIs = levelSettings[stakingInfos[1].level].reverseMFIsPerFragment * tokensToDAO;
        levelSettings[stakingInfos[1].level].lockedReverseMFIs += additionalReverseMFIs;
        stakingInfos[1].reverseMFIs += additionalReverseMFIs;

        delete stakingInfos[tokenId];

        IERC20(contractRegistry.getContractAddress(MFI_HASH)).safeTransfer(owner, tokensToUser);

        emit StakingAccountLiquidated(tokenId, tokensToUser);
    }

    function addTokensToStaking(uint256 tokenId, uint256 numberOfTokens) public onlyRouter notInLiquidation override {

        uint256 additionalReverseMFIs = levelSettings[stakingInfos[tokenId].level].reverseMFIsPerFragment * numberOfTokens;
        levelSettings[stakingInfos[tokenId].level].lockedReverseMFIs += additionalReverseMFIs;
        stakingInfos[tokenId].reverseMFIs += additionalReverseMFIs;

        emit TokensAddedToStaking(tokenId, numberOfTokens);
    }

    function upgradeStakingAccountToLevel(uint256 tokenId, uint256 newLevel) public onlyRouter notInLiquidation override {

        uint256 currentLevel = stakingInfos[tokenId].level;
        levelSettings[currentLevel].lockedReverseMFIs -= stakingInfos[tokenId].reverseMFIs;
        stakingInfos[tokenId].reverseMFIs = stakingInfos[tokenId].reverseMFIs / levelSettings[currentLevel].reverseMFIsPerFragment * levelSettings[newLevel].reverseMFIsPerFragment;
        levelSettings[newLevel].lockedReverseMFIs += stakingInfos[tokenId].reverseMFIs;
        stakingInfos[tokenId].level = newLevel;

        emit StakingAccountUpgraded(tokenId, newLevel, getAccountTokens(tokenId));
    }

    function timeToNextRebase() public view override returns (uint256) {

        if((block.timestamp - lastRebase) < rebaseTimeout) {
            return rebaseTimeout - (block.timestamp - lastRebase);
        }

        return 0;
    }

    function nextRebaseAt() public view override returns (uint256) {
        return lastRebase + rebaseTimeout;
    }

    function rebase() public notInLiquidation override {

        ITreasury treasury = ITreasury(contractRegistry.getContractAddress(TREASURY_HASH));

        if((block.timestamp - lastRebase) < rebaseTimeout) {
            return;
        }

        lastRebase = block.timestamp;

        uint256 additionalTokens = 0;

        uint256 oldTokenNum;
        uint256 newTokenNum;
        LevelSettings memory currentLevelSettings;

        for(uint256 x = 0; x < levelSettings.length; x++) {
            currentLevelSettings = levelSettings[x];
            oldTokenNum = currentLevelSettings.lockedReverseMFIs / currentLevelSettings.reverseMFIsPerFragment;
            levelSettings[x].reverseMFIsPerFragment = currentLevelSettings.reverseMFIsPerFragment * levelSettings[x].rebaseMultiplier / 1000000000;
            newTokenNum = (currentLevelSettings.lockedReverseMFIs / levelSettings[x].reverseMFIsPerFragment);
            additionalTokens += newTokenNum - oldTokenNum;

            emit StakingLevelRebased(x, newTokenNum);
        }

        treasury.distributeStakingRewards(additionalTokens);

        emit StakingRebased(additionalTokens);
    }


    function totalLevels() public view returns (uint256) {
        return levelSettings.length;
    }

    function enterLiquidation() public override onlyTreasury notInLiquidation returns (uint256 totalMFIStaked) {

        IERC20 token = IERC20(contractRegistry.getContractAddress(MFI_HASH));

        totalMFIStaked = token.balanceOf(address(this));

        inLiquidation = true;
        token.safeTransfer(msg.sender, totalMFIStaked);
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury notInLiquidation {

        require(tokenAddress != contractRegistry.getContractAddress(MFI_HASH), "Collection of MFI from staking is not allowed");

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }
}