// SPDX-License-Identifier: MITmont

pragma solidity 0.8.18;

import "../interfaces/IContractRegistry.sol";
import "../interfaces/IManageableTreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MonthlyPayoutController is Ownable {

    event PayoutMade(uint256 amount);

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyReceiver() {
        require(msg.sender == receiver);
        _;
    }
    //---------------------------------------------------------------------------

    uint256 public monthlyPaymentAmount;
    address public receiver;
    address public busdAddress;
    uint256 public totalPaidOut;

    uint256 public deploymentTime;

    uint256 constant averageTimePerMonth = 2628000;

    constructor(
        IContractRegistry _contractRegistry,
        address _busdAddress,
        uint256 _monthlyPaymentAmount,
        address _receiver
    ) {
        contractRegistry = _contractRegistry;
        busdAddress = _busdAddress;
        monthlyPaymentAmount = _monthlyPaymentAmount;
        receiver = _receiver;
        deploymentTime = block.timestamp;
    }

    function doThePayout(uint256 amount) external onlyReceiver {

        require(amount <= fundsAvailable(), "not enough funds available");

        totalPaidOut += amount;

        IManageableTreasury treasury = IManageableTreasury(contractRegistry.getContractAddress(TREASURY_HASH));
        treasury.manage(receiver, busdAddress, amount);

        emit PayoutMade(amount);
    }

    function fundsAvailable() public view returns (uint256) {

        uint256 timePassed = block.timestamp - deploymentTime;
        uint256 index = (timePassed / averageTimePerMonth) + 1;

        return (index * monthlyPaymentAmount) - totalPaidOut;
    }

    function destroy() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }
}