// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTTransferProxy {

    using SafeERC20 for IERC20;

    IContractRegistry public contractRegistry;
    IERC20 public busd;

    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));

    constructor(IContractRegistry _contractRegistry, IERC20 _busd) {
        contractRegistry = _contractRegistry;
        busd = _busd;
    }

    function transferWithFee(uint256 id, address destination) external {
        busd.safeTransferFrom(msg.sender, contractRegistry.getContractAddress(TREASURY_HASH), 10 ** 19);
        IERC721(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).safeTransferFrom(msg.sender, destination, id);
    }

}