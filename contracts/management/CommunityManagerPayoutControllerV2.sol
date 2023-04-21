// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "../ContractRegistryUser.sol";

contract CommunityManagerPayoutControllerV2 is ContractRegistryUser {

    using SafeERC20 for IERC20;
    using Address for address payable;


    event MemberPaid(address memberAddress, uint256 amount);

    struct PayoutMember {
        address memberAddress;

        // 100 => 1 stableCoin
        uint256 stableCoinValue;
    }

    //---------------------------------------------------------------------------

    address public stableCoinAddress;
    uint256 public lastPayout;
    mapping(address => uint256) public totalReceived;

    constructor(IContractRegistry _contractRegistry, address _stableCoinAddress) ContractRegistryUser(_contractRegistry) {
        require(_stableCoinAddress != address(0), "_stableCoinAddress cannot be 0x0");
        contractRegistry = _contractRegistry;
        stableCoinAddress = _stableCoinAddress;
    }

    function doThePayout(PayoutMember[] calldata payoutMembers) public {
        onlyRealmGuardian();
        //Max once every 27 days
        require((lastPayout + (27 days)) < block.timestamp, "timelock");
        lastPayout = block.timestamp;

        IManageableTreasury treasury = IManageableTreasury(contractRegistry.getContractAddress(TREASURY_HASH));

        uint256 total = 0;
        for (uint256 x = 0; x < payoutMembers.length; x++) {
            total += payoutMembers[x].stableCoinValue;
            totalReceived[payoutMembers[x].memberAddress] += payoutMembers[x].stableCoinValue;

            treasury.manage(payoutMembers[x].memberAddress,
                stableCoinAddress, payoutMembers[x].stableCoinValue * (10 ** IERC20Metadata(stableCoinAddress).decimals()) / 100);

            emit MemberPaid(payoutMembers[x].memberAddress, payoutMembers[x].stableCoinValue);
        }

        //Limit to 10k per total payout
        require(total < 1000000, "10k limit");
    }

    function changePaymentToken(address _stableCoinAddress) public {
        onlyRealmGuardian();
        require(_stableCoinAddress != address(0), "stableCoinAddress cannot be null");
        stableCoinAddress = _stableCoinAddress;
    }

    function disable() public {
        onlyRealmGuardian();
        lastPayout = type(uint256).max;
        // disable further payouts, will panic with overflow on next payout attempt
        if (address(this).balance > 0) {
            payable(msg.sender).sendValue(address(this).balance);
        }
    }

}