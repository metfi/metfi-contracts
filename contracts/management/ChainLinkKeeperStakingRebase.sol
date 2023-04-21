//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../interfaces/KeeperCompatibleInterface.sol";
import "../interfaces/IContractRegistry.sol";

interface IRebaseableStakingManager {
    function timeToNextRebase() external view returns (uint256);
    function rebase() external;
}

contract ChainLinkKeeperStakingRebaseProxy is KeeperCompatibleInterface {

    IContractRegistry contractRegistry;
    bytes32 constant STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));

    constructor(IContractRegistry _contractRegistry) {
        contractRegistry = _contractRegistry;
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory x) {
        return (IRebaseableStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH)).timeToNextRebase() == 0, x);
    }

    function performUpkeep(bytes calldata) external override {
        IRebaseableStakingManager(contractRegistry.getContractAddress(STAKING_MANAGER_HASH)).rebase();
    }

}