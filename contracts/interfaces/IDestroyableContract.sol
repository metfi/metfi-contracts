// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IDestroyableContract {
    function destroyContract(address payable to) external;
}