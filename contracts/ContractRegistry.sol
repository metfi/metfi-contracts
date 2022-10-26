// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMatrix.sol";
import "./interfaces/IBuybackController.sol";

contract ContractRegistry is IContractRegistry {

    mapping(bytes32 => address) contractAddresses;
    mapping(string => ILiquidityController) liquidityControllers;
    mapping(address => address) priceCalcAddresses;
    mapping(string => IBuybackController) buybackControllers;
    mapping(address => bool) realmGuardians;
    mapping(address => bool) coinMasters;

    IMatrix[] public matrices;

    constructor() {
        realmGuardians[msg.sender] = true;
    }

    modifier onlyRealmGuardian() {
        require(isRealmGuardian(msg.sender));
        _;
    }

    function contractAddressExists(bytes32 nameHash) public view override returns (bool) {
        return contractAddresses[nameHash] != address(0);
    }

    function matrixExists(uint256 level) public view override returns (bool) {
        return matrices.length > level;
    }

    function liquidityControllerExists(string calldata name) public view override returns (bool) {
        return address(liquidityControllers[name]) != address(0);
    }

    function buybackControllerExists(string calldata name) public view override returns (bool) {
        return address(buybackControllers[name]) != address(0);
    }

    function priceCalculatorExists(address currency) public view override returns (bool) {
        return priceCalcAddresses[currency] != address(0);
    }

    function getContractAddress(bytes32 nameHash) public view override returns (address) {
        require(contractAddresses[nameHash] != address(0), 'Contract address does not exist');
        return contractAddresses[nameHash];
    }

    function getMatrix(uint256 level) public view override returns (IMatrix) {
        require(matrices.length > level, 'Matrix does not exist');
        return matrices[level];
    }

    function getLiquidityController(string calldata name) public view override returns (ILiquidityController) {
        require(address(liquidityControllers[name]) != address(0), 'Liquidity controller address does not exist');
        return liquidityControllers[name];
    }

    function getBuybackController(string calldata name) public view override returns (IBuybackController) {
        require(address(buybackControllers[name]) != address(0), 'Buyback controller address does not exist');
        return buybackControllers[name];
    }

    function getPriceCalculator(address currency) public view override returns (address) {
        require(priceCalcAddresses[currency] != address(0), 'Price calculator address does not exist');
        return priceCalcAddresses[currency];
    }

    function isRealmGuardian(address guardianAddress) public view override returns (bool) {
        return realmGuardians[guardianAddress];
    }

    function isCoinMaster(address masterAddress) public view override returns (bool) {
        return coinMasters[masterAddress];
    }

    function setContractAddress(string calldata name, address newAddress) public onlyRealmGuardian {
        contractAddresses[keccak256(abi.encodePacked(name))] = newAddress;
    }

    function setMatrixAddress(uint256 level, address newAddress) public onlyRealmGuardian {
        matrices[level] = IMatrix(newAddress);
    }

    function addMatrixLevel(address newAddress) public onlyRealmGuardian {
        matrices.push(IMatrix(newAddress));
    }

    function setLiquidityControllerAddress(string calldata name, ILiquidityController newController) public onlyRealmGuardian {
        liquidityControllers[name] = newController;
    }

    function setBuybackControllerAddress(string calldata name, IBuybackController newController) public onlyRealmGuardian {
        buybackControllers[name] = newController;
    }

    function setPriceCalcAddress(address currencyAddress, address newAddress) public onlyRealmGuardian {
        priceCalcAddresses[currencyAddress] = newAddress;
    }

    function setRealmGuardian(address guardianAddress, bool admitted) public onlyRealmGuardian {
        realmGuardians[guardianAddress] = admitted;
    }

    function setCoinMaster(address masterAddress, bool admitted) public onlyRealmGuardian {
        coinMasters[masterAddress] = admitted;
    }

}