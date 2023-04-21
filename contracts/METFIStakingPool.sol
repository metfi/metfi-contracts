// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract METFIStakingPool is ContractRegistryUser, IMETFIStakingPool {

    using SafeERC20 for IERC20;

    uint256 METFIPercentagePerPeriod;

    constructor(IContractRegistry _contractRegistry, uint256 _METFIPercentagePerPeriod) ContractRegistryUser(_contractRegistry) {
        require(_METFIPercentagePerPeriod <= 10000, "Invalid METFI percentage per period");
        METFIPercentagePerPeriod = _METFIPercentagePerPeriod;
    }


    function withdrawMETFIForNextStakingPeriod() external override returns (uint256) {
        onlyStakingManager();

        uint256 amount = getMETFIERC20().balanceOf(address(this)) * METFIPercentagePerPeriod / 10000;

        getMETFIERC20().safeTransfer(msg.sender, amount);

        emit METFIWithdrawnForNextStakingPeriod(msg.sender, amount);

        return amount;
    }

    function withdrawMETFI(address to, uint256 METFIAmount) external override {
        onlyStakingManagerOrTokenCollector();

        getMETFIERC20().safeTransfer(to, METFIAmount);

        emit METFIWithdrawn(to, METFIAmount);
    }

    function migratePool(address newPool) external {
        onlyRealmGuardian();

        require(newPool != address(0), "Invalid address");

        uint256 totalAmount = getMETFIERC20().balanceOf(address(this));
        getMETFIERC20().safeTransfer(newPool, totalAmount);

        emit METFIStakingPoolMigrated(newPool, totalAmount);
    }


    function burnFromPool(uint256 amount) external {
        onlyRealmGuardian();

        IERC20 metfi = getMETFIERC20();

        require(amount <= metfi.balanceOf(address(this)), "Invalid amount");
        require(amount > 0, "Invalid amount");

        IBurnControllerV2 burnController = getBurnController();

        metfi.approve(address(burnController), amount);
        burnController.burnWithTransfer(amount);

        emit METFIBurnedFromPool(amount);
    }


    function setMETFIPercentagePerPeriod(uint256 _METFIPercentagePerPeriod) external {
        onlyRealmGuardian();
        require(_METFIPercentagePerPeriod <= 10000, "Invalid METFI percentage per period");
        METFIPercentagePerPeriod = _METFIPercentagePerPeriod;

        emit METFIPercentageForPeriodChanged(_METFIPercentagePerPeriod);
    }

    /**
    @notice Gets lost tokens, that have been sent to this contract by mistake.
    @param tokenAddress The address of the token to withdraw.
    */
    function getLostTokens(address tokenAddress) public override {

        if (contractRegistry.getContractAddress(METFI_HASH) == tokenAddress) {
            revert METFINotWithdrawable();
        }

        super.getLostTokens(tokenAddress);

    }
}