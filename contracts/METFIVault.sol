// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

contract METFIVault is IMETFIVault, ContractRegistryUser {

    using SafeERC20 for IERC20;

    constructor(IContractRegistry _contractRegistry) ContractRegistryUser(_contractRegistry) {}

    function withdrawMETFI(address to, uint256 amount) external override {

        coinMasterTreasuryOrTokenCollector();

        require(to != address(0), "Invalid address");
        if (amount == 0) {
            return;
        }

        getMETFIERC20().safeTransfer(to, amount);

        emit METFIWithdrawn(to, amount);
    }

    function coinMasterTreasuryOrTokenCollector() internal view {
        if (contractRegistry.isCoinMaster(msg.sender)) return;
        if (msg.sender == contractRegistry.getContractAddress(TREASURY_HASH)) return;
        if (msg.sender == contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)) return;

        revert("Coin master, treasury or token collector");
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