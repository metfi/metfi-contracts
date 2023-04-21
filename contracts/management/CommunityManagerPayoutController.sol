// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../interfaces/IContractRegistry.sol";
import "../interfaces/IManageableTreasury.sol";

contract CommunityManagerPayoutController {

    event MemberPaid(address memberAddress, uint256 amount);

    struct PayoutMember {
        address memberAddress;

        //100 => 1BUSD
        uint256 busdValue;
    }

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyRealmGuardian() {
        require(contractRegistry.isRealmGuardian(msg.sender));
        _;
    }
    //---------------------------------------------------------------------------

    address public busdAddress;
    uint256 public lastPayout;
    mapping(address => uint256) public totalReceived;

    constructor(IContractRegistry _contractRegistry, address _busdAddress) {
        contractRegistry = _contractRegistry;
        busdAddress = _busdAddress;
    }

    function doThePayout(PayoutMember[] calldata payoutMembers) public onlyRealmGuardian {

        //Max once every 27 days
        require((lastPayout + (27 days)) < block.timestamp, "timelock");
        lastPayout = block.timestamp;

        IManageableTreasury treasury = IManageableTreasury(contractRegistry.getContractAddress(TREASURY_HASH));

        uint256 total = 0;
        for (uint256 x = 0; x < payoutMembers.length; x++) {
            total += payoutMembers[x].busdValue;
            totalReceived[payoutMembers[x].memberAddress] += payoutMembers[x].busdValue;

            treasury.manage(payoutMembers[x].memberAddress, busdAddress, payoutMembers[x].busdValue * (10 ** 16));

            emit MemberPaid(payoutMembers[x].memberAddress, payoutMembers[x].busdValue);
        }

        //Limit to 10k per total payout
        require(total < 1000000, "10k limit");
    }

    function destroy() public onlyRealmGuardian {
        selfdestruct(payable(msg.sender));
    }

}