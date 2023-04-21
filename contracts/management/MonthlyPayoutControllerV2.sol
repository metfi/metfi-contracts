// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "../ContractRegistryUser.sol";

contract MonthlyPayoutControllerV2 is ContractRegistryUser {

    using SafeERC20 for IERC20;
    using Address for address payable;

    event PayoutMade(uint256 amount);

    //----------------- Access control ------------------------------------------

    function onlyReceiver() internal view {
        require(msg.sender == receiver, "onlyReceiver");
    }
    //---------------------------------------------------------------------------

    uint256 public monthlyPaymentAmount;
    address public immutable receiver;
    address public stableCoinAddress;
    uint256 public totalPaidOut;

    uint256 public immutable deploymentTime;

    uint256 constant averageTimePerMonth = 2628000;

    constructor(
        IContractRegistry _contractRegistry,
        address _stableCoinAddress,
        uint256 _monthlyPaymentAmount,
        address _receiver
    ) ContractRegistryUser(_contractRegistry) {
        require(_stableCoinAddress != address(0), "stableCoinAddress cannot be 0x0");
        require(_receiver != address(0), "receiver cannot be 0x0");
        require(_monthlyPaymentAmount > 0, "monthlyPaymentAmount cannot be 0");
        stableCoinAddress = _stableCoinAddress;
        monthlyPaymentAmount = _monthlyPaymentAmount;
        receiver = _receiver;
        deploymentTime = block.timestamp;
    }

    function doThePayout(uint256 amount) external {
        onlyReceiver();

        require(amount > 0, "amount must be greater than 0");
        require(amount <= fundsAvailable(), "not enough funds available");

        totalPaidOut += amount;

        IManageableTreasury treasury = IManageableTreasury(contractRegistry.getContractAddress(TREASURY_HASH));
        treasury.manage(receiver, stableCoinAddress, amount);

        emit PayoutMade(amount);
    }

    function fundsAvailable() public view returns (uint256) {

        uint256 timePassed = block.timestamp - deploymentTime;
        uint256 index = (timePassed / averageTimePerMonth) + 1;

        return (index * monthlyPaymentAmount) - totalPaidOut;
    }

    function setStableCoinAddress(address _stableCoinAddress) external {
        onlyRealmGuardian();
        require(_stableCoinAddress != address(0), "stableCoinAddress cannot be 0x0");
        if (IERC20Metadata(stableCoinAddress).decimals != IERC20Metadata(_stableCoinAddress).decimals) {
            monthlyPaymentAmount = monthlyPaymentAmount * (10 ** IERC20Metadata(_stableCoinAddress).decimals()) / (10 ** IERC20Metadata(stableCoinAddress).decimals());
            totalPaidOut = totalPaidOut * (10 ** IERC20Metadata(_stableCoinAddress).decimals()) / (10 ** IERC20Metadata(stableCoinAddress).decimals());
        }
        stableCoinAddress = _stableCoinAddress;
    }

    function destroy() external {
        onlyRealmGuardian();
        monthlyPaymentAmount = 0;
        if (address(this).balance > 0) {
            payable(msg.sender).sendValue(address(this).balance);
        }
    }
}