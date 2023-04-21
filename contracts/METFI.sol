// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ContractRegistryUser.sol";

// @custom:security-contact info@metfi.io
contract METFI is IMETFI, ERC20Permit, ContractRegistryUser {

    using SafeERC20 for IERC20;

    //----------------- Access control ------------------------------------------
    address public securityProxy;
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry) ERC20("MetFi", "METFI") ERC20Permit("metfi") ContractRegistryUser(_contractRegistry) {
        securityProxy = address(0);

        super._mint(msg.sender, 500_000_000 * (10 ** 18));
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    override
    {

        if (securityProxy != address(0)) {
            require(ISecurityProxy(securityProxy).validateTransfer(from, to, amount), "Transfer not allowed");
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function setSecurityProxy(address _securityProxy) external {
        onlyRealmGuardian();
        securityProxy = _securityProxy;
    }

}