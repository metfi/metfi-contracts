// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IUserConfig.sol";
import "./interfaces/IDestroyableContract.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";


contract UserConfig is IUserConfig, IDestroyableContract, ILostTokenProvider {

    using SafeERC20 for IERC20;

    //----------------- Access control -------------------------------------------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant ROUTER_HASH = keccak256(abi.encodePacked('router'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyRealmGuardian() {
        require(contractRegistry.isRealmGuardian(msg.sender), "Only realm guardian");
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH), "Only treasury");
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == contractRegistry.getContractAddress(ROUTER_HASH), "Only router");
        _;
    }
    //----------------------------------------------------------------------------------------------------------------

    string[] public allowedStringValueKeys;
    string[] public allowedUintValueKeys;

    mapping(uint256 => mapping(string => uint256)) uintValues;
    mapping(uint256 => mapping(string => string)) stringValues;

    constructor(IContractRegistry _contractRegistry){
        contractRegistry = _contractRegistry;
        allowedUintValueKeys.push("is_crypto");
        emit AllowedUintKeyAdded("is_crypto");
    }


    function getAllUserConfigValues(uint256 nftId) external override view returns (UserConfigValues memory values) {

        values = UserConfigValues({
        uintValues: new UserConfigUintValue[](allowedUintValueKeys.length),
        stringValues: new UserConfigStringValue[](allowedStringValueKeys.length)
        });

        for (uint256 i = 0; i < allowedUintValueKeys.length; i++) {
            values.uintValues[i] = (UserConfigUintValue({
            key: allowedUintValueKeys[i],
            value: uintValues[nftId][allowedUintValueKeys[i]]
            }));
        }

        for (uint256 i = 0; i < allowedStringValueKeys.length; i++) {
            values.stringValues[i] = (UserConfigStringValue({
            key: allowedStringValueKeys[i],
            value: stringValues[nftId][allowedStringValueKeys[i]]
            }));
        }
    }

    function getUserConfigUintValue(uint256 nftId, string memory key) external override view returns (uint256 value){
        require(isAllowedUintValueKey(key), "UserConfig: key not allowed");
        return uintValues[nftId][key];
    }

    function getUserConfigStringValue(uint256 nftId, string memory key) external override view returns (string memory value) {
        require(isAllowedStringValueKey(key), "UserConfig: key not allowed");
        return stringValues[nftId][key];
    }

    function setUserConfigUintValue(uint256 nftId, string memory key, uint256 value) external override onlyRouter {
        require(isAllowedUintValueKey(key), "UserConfig: key not allowed");
        uint256 oldValue = uintValues[nftId][key];
        uintValues[nftId][key] = value;
        emit UserConfigUintValueUpdated(msg.sender, key, oldValue, value);
    }

    function setUserConfigStringValue(uint256 nftId, string memory key, string memory value) external override onlyRouter {
        require(isAllowedStringValueKey(key), "UserConfig: key not allowed");
        string memory oldValue = stringValues[nftId][key];
        stringValues[nftId][key] = value;
        emit UserConfigStringValueUpdated(msg.sender, key, oldValue, value);
    }

    function isAllowedStringValueKey(string memory key) public view returns (bool) {
        for (uint256 i = 0; i < allowedStringValueKeys.length; i++) {
            if (keccak256(abi.encodePacked(allowedStringValueKeys[i])) == keccak256(abi.encodePacked(key))) {
                return true;
            }
        }
        return false;
    }

    function isAllowedUintValueKey(string memory key) public view returns (bool) {
        for (uint256 i = 0; i < allowedUintValueKeys.length; i++) {
            if (keccak256(abi.encodePacked(allowedUintValueKeys[i])) == keccak256(abi.encodePacked(key))) {
                return true;
            }
        }
        return false;
    }


    function addAllowedStringValueKey(string memory key) external onlyRealmGuardian {
        require(!isAllowedStringValueKey(key), "UserConfig: key already allowed");
        allowedStringValueKeys.push(key);
        emit AllowedStringKeyAdded(key);
    }

    function addAllowedUintValueKey(string memory key) external onlyRealmGuardian {
        require(!isAllowedUintValueKey(key), "UserConfig: key already allowed");
        allowedUintValueKeys.push(key);
        emit AllowedUintKeyAdded(key);
    }

    function getLostTokens(address tokenAddress) external override onlyTreasury {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function destroyContract(address payable to) external override onlyTreasury {
        selfdestruct(to);
    }

}