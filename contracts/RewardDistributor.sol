// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IMatrix.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IContractRegistry.sol";
import "./ContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";

contract RewardDistributor is IRewardDistributor, ILostTokenProvider, IDestroyableContract {

    using SafeERC20 for IERC20;

    mapping(uint256 => RewardAccountInfo) public accounts;
    uint256 bonusActivationTimeout;

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant ROUTER_HASH = keccak256(abi.encodePacked('router'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyRouter() {
        require(msg.sender == contractRegistry.getContractAddress(ROUTER_HASH));
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }

    modifier onlyRealmGuardian() {
        require(contractRegistry.isRealmGuardian(msg.sender));
        _;
    }
    //---------------------------------------------------------------------------

    constructor(
        ContractRegistry _contractRegistry,
        uint256 _bonusActivationTimeout
    ) {

        contractRegistry = _contractRegistry;
        bonusActivationTimeout = _bonusActivationTimeout;

        accounts[1] = RewardAccountInfo(1, 0, 0, 0, 0, 0, 0, true, false);
    }

    function getAccountInfo(uint256 nftId) public view override returns (RewardAccountInfo memory) {
        return accounts[nftId];
    }

    function createAccount(uint256 nftId, uint256 parentId) public onlyRouter override {
        accounts[nftId] = RewardAccountInfo(nftId, parentId, 0, 0, 0, uint64(block.timestamp + bonusActivationTimeout), 0, false, false);
    }

    function accountUpgraded(uint256 nftId, uint256 level) public onlyRouter override {
        if (level == 3) {
            uint256 directUplinkId = accounts[nftId].directUplink;
            RewardAccountInfo storage directUplink = accounts[directUplinkId];
            if (block.timestamp < directUplink.bonusDeadline && !directUplink.accountLiquidated) {
                directUplink.activeBonusUsers++;
                if (directUplink.activeBonusUsers == 5) {

                    directUplink.bonusActive = true;
                    claimInitialFastStart(directUplink.ID);

                    emit BonusActivated(nftId);
                }
            }
        }
    }

    function liquidateAccount(uint256 nftId) public onlyRouter override {
        accounts[nftId].accountLiquidated = true;
    }

    function distributeRewards(uint256 distributionValue, uint256 rewardType, uint256 nftId, uint256 level) public onlyRouter override {

        ITreasury treasury = ITreasury(contractRegistry.getContractAddress(TREASURY_HASH));

        uint256 distributionPercentage;
        if(rewardType == 0) {
            distributionPercentage = 5;
        }else if(rewardType == 1) {
            distributionPercentage = 1;
        }else {
            revert("Unknown reward type");
        }

        //Increase fast start bonus if applicable
        RewardAccountInfo memory currentAccount = accounts[nftId];

        //Send/add fast start bonus
        if(rewardType == 0) {
            handleFastStartBonus(currentAccount.directUplink, nftId, distributionValue / 10);
        }

        //Get nodes that receive bonus from matrix
        uint256[] memory distributionNodes = contractRegistry.getMatrix(level).getDistributionNodes(nftId);

        uint256 distributionAmount = distributionValue * distributionPercentage / 100;
        uint256 matchingBonusAmount = distributionAmount * 50 / 100;

        for (uint256 x = 0; x < distributionNodes.length; x++) {

            //Copy account to memory to lower gas costs on reading
            currentAccount = accounts[distributionNodes[x]];

            //Liquidated accounts don't receive rewards
            if (currentAccount.accountLiquidated) continue;

            //Send matrix rewards and increase total counter
            treasury.sendReward(distributionNodes[x], distributionAmount);
            accounts[distributionNodes[x]].receivedMatrixBonus += distributionAmount;
            emit RewardSent(currentAccount.ID, nftId, rewardType, level, x, distributionAmount);

            //Pay out matching bonus
            if (currentAccount.directUplink > 0) {
                if (accounts[currentAccount.directUplink].bonusActive && !accounts[currentAccount.directUplink].accountLiquidated) {

                    treasury.sendReward(currentAccount.directUplink, matchingBonusAmount);
                    accounts[currentAccount.directUplink].receivedMatchingBonus += matchingBonusAmount;

                    emit MatchingBonusSent(currentAccount.directUplink, currentAccount.ID, matchingBonusAmount);
                }
            }
        }
    }

    function handleFastStartBonus(uint256 nftId, uint256 from, uint256 amount) internal {

        if (block.timestamp < accounts[nftId].bonusDeadline && !accounts[nftId].accountLiquidated) {

            accounts[nftId].fastStartBonus += amount;

            if (accounts[nftId].bonusActive) {

                ITreasury treasury = ITreasury(contractRegistry.getContractAddress(TREASURY_HASH));
                treasury.sendReward(nftId, amount);
            }

            emit FastStartBonusReceived(nftId, from, amount, accounts[nftId].bonusActive);
        }
    }

    function claimInitialFastStart(uint256 nftId) internal {
        ITreasury treasury = ITreasury(contractRegistry.getContractAddress(TREASURY_HASH));
        treasury.sendReward(nftId, accounts[nftId].fastStartBonus);
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function setBonusActivationTimeout(uint256 newBonusActivationTimeout) public onlyRealmGuardian {
        bonusActivationTimeout = newBonusActivationTimeout;
    }

    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }

}