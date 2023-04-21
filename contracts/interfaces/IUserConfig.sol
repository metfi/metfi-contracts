// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IUserConfig {

    event UserConfigUintValueUpdated(address indexed user, string indexed key, uint256 old_value, uint256 new_value);
    event UserConfigStringValueUpdated(address indexed user, string indexed key, string old_value, string new_value);
    event AllowedStringKeyAdded(string key);
    event AllowedUintKeyAdded(string key);

    struct UserConfigUintValue {
        string key;
        uint256 value;
    }

    struct UserConfigStringValue {
        string key;
        string value;
    }

    struct UserConfigValues {
        UserConfigUintValue[] uintValues;
        UserConfigStringValue[] stringValues;
    }

    function getAllUserConfigValues(uint256 nftId) external view returns (UserConfigValues memory values);
    function getUserConfigUintValue(uint256 nftId, string memory key) external view returns (uint256 value);
    function getUserConfigStringValue(uint256 nftId, string memory key) external view returns (string memory value);

    function setUserConfigUintValue(uint256 nftId, string memory key, uint256 value) external;
    function setUserConfigStringValue(uint256 nftId, string memory key, string memory value) external;

}
