// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract BurnControllerV2 is IBurnControllerV2, ContractRegistryUser {

    using SafeERC20 for IMETFI;

    uint256 public recyclePercentage; // 1e9 = 100%
    uint256 public starAchieversPercentage; // 1e9 = 100%
    uint256 public vaultPercentage; // 1e9 = 100%

    constructor(IContractRegistry _contractRegistry, uint256 _recyclePercentage, uint256 _starAchieversPercentage, uint256 _vaultPercentage) ContractRegistryUser(_contractRegistry) {

        require(_recyclePercentage + _starAchieversPercentage + _vaultPercentage <= 1e9, "Invalid recycle percentage");

        recyclePercentage = _recyclePercentage;
        starAchieversPercentage = _starAchieversPercentage;
        vaultPercentage = _vaultPercentage;
    }

    function burnExisting() public {

        IMETFI metfi = getMETFI();

        uint256 amount = metfi.balanceOf(address(this));
        uint256 recycleAmount = amount * recyclePercentage / 1e9;
        uint256 starAchieversAmount = amount * starAchieversPercentage / 1e9;
        uint256 vaultAmount = amount * vaultPercentage / 1e9;

        if (amount > 0) {
            metfi.burn(amount - (recycleAmount + starAchieversAmount + vaultAmount));
            metfi.safeTransfer(contractRegistry.getContractAddress(METFI_STAKING_POOL_HASH), recycleAmount);
            metfi.safeTransfer(contractRegistry.getContractAddress(STAR_ACHIEVERS_HASH), starAchieversAmount);
            metfi.safeTransfer(contractRegistry.getContractAddress(METFI_VAULT_HASH), vaultAmount);
        }
    }

    function burnWithTransfer(uint256 amount) external {

        getMETFI().safeTransferFrom(msg.sender, address(this), amount);

        burnExisting();
    }

    function setRecyclePercentage(uint256 _recyclePercentage) external {
        onlyRealmGuardian();

        require((_recyclePercentage + starAchieversPercentage + vaultPercentage) <= 1e9, "Invalid recycle percentage");
        recyclePercentage = _recyclePercentage;
    }

    function setStarAchieversPercentage(uint256 _starAchieversPercentage) external {
        onlyRealmGuardian();

        require((_starAchieversPercentage + recyclePercentage + vaultPercentage) <= 1e9, "Invalid star achievers percentage");
        starAchieversPercentage = _starAchieversPercentage;
    }

    function setVaultPercentage(uint256 _vaultPercentage) external {
        onlyRealmGuardian();

        require((_vaultPercentage + recyclePercentage + starAchieversPercentage) <= 1e9, "Invalid vault percentage");
        vaultPercentage = _vaultPercentage;
    }

}