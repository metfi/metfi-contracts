// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface IMultiSigStructs {

    struct Action {
        uint256 actionType;
        string requestId;
        bytes data;
        uint256 executionAvailableTime;
        bool executed;
        bool vetoed;
        address creator;
    }

    struct MultiSigAccount {
        address accountAddress;
        address votingAddress;
    }


}