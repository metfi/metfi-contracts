// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IContractRegistry.sol";

contract MetFi is ERC20 {

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant TOKEN_COLLECTOR_HASH = keccak256(abi.encodePacked('token_collector'));
    bytes32 constant STAKING_MANAGER_HASH = keccak256(abi.encodePacked('staking_manager'));

    modifier collectorOrTreasury() {
        require(
            msg.sender == contractRegistry.getContractAddress(TREASURY_HASH) ||
            msg.sender == contractRegistry.getContractAddress(TOKEN_COLLECTOR_HASH)
        );
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry) ERC20("MetFi", "MFI") {
        contractRegistry = _contractRegistry;

        _mint(contractRegistry.getContractAddress(STAKING_MANAGER_HASH), 112530 * (10 ** 18));
    }

    function mint(address to, uint256 amount) public collectorOrTreasury {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyTreasury {
        _burn(from, amount);
    }
}