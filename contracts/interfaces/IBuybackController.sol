// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IBuybackController {

    event BoughtBackMFI(address indexed token, uint256 tokenAmount, uint256 mfiReceived);

    function buyBackMFI(address token, uint256 tokenAmount, uint256 minMFIOut) external;

}