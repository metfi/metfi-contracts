// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/IMetFiNFTMarket.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";
import "./interfaces/IContractRegistry.sol";


contract MetFiNFTMarket is IMetFiNFTMarket, Ownable, IDestroyableContract, EIP712 {

    using SafeERC20 for IERC20;

    //----------------- Access control -------------------------------------------------------------------------------
    IContractRegistry internal contractRegistry;
    bytes32 constant MFI_HASH = keccak256(abi.encodePacked('mfi'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));
    mapping(address => bool) internal feeManager;

    modifier onlyFeeManager() {
        require(feeManager[msg.sender], "Unapproved fee manager");
        _;
    }

    modifier checkListingData(ListingData calldata listingData, address paymentCurrency) {
        {// Wrapped to avoid stack too deep error
            require(block.timestamp <= listingData.deadline, "Listing expired");

            bytes32 listingHash = getListingDataHash(listingData);

            require(!revokedListingHashes[listingHash], "Listing revoked");

            address seller = ECDSA.recover(listingHash, listingData.signature);
            require(seller == listingData.tokenOwner, "Bad listing request");

            require(IERC721(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH))
            .ownerOf(listingData.tokenId) == listingData.tokenOwner, "Wrong owner of this NFT");

            require(
                paymentCurrencies[listingData.currency] && paymentCurrencies[paymentCurrency],
                "Unapproved payment currency"
            );
        }
        _;
    }

    //----------------------------------------------------------------------------------------------------------------

    IPancakeRouter02 internal immutable pancakeRouter;
    address public constant busdAddress = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;


    mapping(address => bool) internal paymentCurrencies;
    mapping(address => uint256) marketRoyaltiesPerCurrency;
    mapping(address => uint256) treasuryRoyaltiesPerCurrency;

    mapping(bytes32 => bool) internal revokedListingHashes;

    constructor(IContractRegistry _contractRegistry) EIP712 ("MetFiNFTMarket", "1") {
        contractRegistry = _contractRegistry;
        pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        treasuryRoyaltiesPerCurrency[busdAddress] = 1000;
        paymentCurrencies[busdAddress] = true;

        address mfiAddress = contractRegistry.getContractAddress(MFI_HASH);
        treasuryRoyaltiesPerCurrency[mfiAddress] = 1000;
        paymentCurrencies[mfiAddress] = true;
    }


    function buyNFT(ListingData calldata listingData, address paymentCurrency)
    override
    external
    checkListingData(listingData, paymentCurrency) {

        // Check balances and allowances, convert payment currency if needed, calculate royalties and transfer funds
        checkAndTransferFunds(listingData, paymentCurrency);

        // Transfer NFT to new Owner
        IERC721(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).safeTransferFrom(
            listingData.tokenOwner,
            msg.sender,
            listingData.tokenId
        );

        emit NFTSold(listingData.tokenId, paymentCurrency, listingData.amount);

    }

    function checkAndTransferFunds(ListingData calldata listingData, address paymentCurrency) private {

        uint256 amountInListingCurrency =
        (listingData.amount * (10 ** IERC20Metadata(listingData.currency).decimals())) / 10000;

        uint256 royaltyAmount = (amountInListingCurrency * treasuryRoyaltiesPerCurrency[listingData.currency]) / 10000;

        uint256 marketFee = (amountInListingCurrency * marketRoyaltiesPerCurrency[listingData.currency]) / 10000;
        uint256 amountReceived = amountInListingCurrency - royaltyAmount - marketFee;

        if (listingData.currency == paymentCurrency) {

            require(
                IERC20(listingData.currency).balanceOf(msg.sender) >= amountInListingCurrency,
                "Buyer doesn't have enough tokens to cover this transaction"
            );

            require(
                IERC20(listingData.currency).allowance(msg.sender, address(this)) >= amountInListingCurrency,
                "Buyer didn't approve this contract to spend (enough of) his tokens"
            );

            IERC20(listingData.currency).safeTransferFrom(msg.sender, listingData.tokenOwner, amountReceived);

            if (royaltyAmount + marketFee > 0) {
                IERC20(listingData.currency).safeTransferFrom(msg.sender, address(this), royaltyAmount + marketFee);
                if (royaltyAmount > 0) {
                    transferRoyaltiesToTreasury(royaltyAmount, listingData.currency);
                }
            }

        } else {

            address[] memory path = new address[](2);
            path[0] = paymentCurrency;
            path[1] = listingData.currency;

            uint256 amountInPaymentCurrency = pancakeRouter.getAmountsIn(amountInListingCurrency, path)[0];

            require(
                IERC20(paymentCurrency).balanceOf(msg.sender) >= amountInPaymentCurrency,
                "Buyer doesn't have enough tokens to cover this transaction"
            );

            require(
                IERC20(paymentCurrency).allowance(msg.sender, address(this)) >= amountInPaymentCurrency,
                "Buyer didn't approve this contract to spend (enough of) his tokens"
            );


            IERC20(paymentCurrency).safeTransferFrom(msg.sender, address(this), amountInPaymentCurrency);

            IERC20(paymentCurrency).safeApprove(address(pancakeRouter), amountInPaymentCurrency);

            pancakeRouter.swapTokensForExactTokens(
                amountInListingCurrency,
                amountInPaymentCurrency,
                path,
                address(this),
                block.timestamp + 60);

            IERC20(listingData.currency).safeTransfer(listingData.tokenOwner, amountReceived);

            if (royaltyAmount > 0) {
                transferRoyaltiesToTreasury(royaltyAmount, listingData.currency);
            }

        }
        if (marketFee > 0) {
            emit MarketRoyaltyFeePaid(listingData.currency, marketFee);
        }
    }

    function transferRoyaltiesToTreasury(uint256 amount, address currency) private {
        address treasury = contractRegistry.getContractAddress(TREASURY_HASH);

        if (currency == contractRegistry.getContractAddress(MFI_HASH)) {
            address[] memory path = new address[](2);
            path[0] = currency;
            path[1] = busdAddress;

            IERC20(currency).safeApprove(address(pancakeRouter), amount);

            uint[] memory swappedAmounts = pancakeRouter.swapExactTokensForTokens(
                amount,
                0,
                path,
                treasury,
                block.timestamp + 60);
            emit TreasuryRoyaltyFeePaid(busdAddress, swappedAmounts[1]);

        } else {
            IERC20(currency).safeTransfer(treasury, amount);
            emit TreasuryRoyaltyFeePaid(currency, amount);
        }

    }

    function revokeListing(ListingData calldata listingData) override external {

        bytes32 listingHash = getListingDataHash(listingData);
        require(!revokedListingHashes[listingHash], "Listing already revoked");

        address seller = ECDSA.recover(listingHash, listingData.signature);
        require(seller == listingData.tokenOwner, "Bad listing request");

        require(msg.sender == seller, "Only the seller can revoke his listing");

        revokedListingHashes[listingHash] = true;

        emit NFTListingRevoked(listingData.tokenId, listingHash);
    }

    function getListingDataHash(ListingData calldata listingData) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
                keccak256("ListingData(uint256 tokenId,address tokenOwner,uint256 listingNonce,address currency,uint256 amount,uint256 deadline)"),
                listingData.tokenId,
                listingData.tokenOwner,
                listingData.listingNonce,
                listingData.currency,
                listingData.amount,
                listingData.deadline
            )));
    }

    function isListingRevoked(bytes32 listingHash) override external view returns (bool) {
        return revokedListingHashes[listingHash];
    }

    function getTotalRoyaltiesForCurrency(address currency) override external view returns (uint256, uint256, uint256) {
        require(paymentCurrencies[currency], "Currency not supported");
        return (
        treasuryRoyaltiesPerCurrency[currency] + marketRoyaltiesPerCurrency[currency],
        marketRoyaltiesPerCurrency[currency],
        treasuryRoyaltiesPerCurrency[currency]);
    }

    function setPaymentCurrency(address currency, bool enabled) external onlyOwner {
        paymentCurrencies[currency] = enabled;
    }

    function setTreasuryRoyaltiesPerCurrency(address currency, uint256 amount) external onlyOwner {
        require(
            amount + marketRoyaltiesPerCurrency[currency] <= 10000,
            "Amount of both royalties must be equal to or bellow 10000 (100%)"
        );
        treasuryRoyaltiesPerCurrency[currency] = amount;
    }

    function setMarketRoyaltiesPerCurrency(address currency, uint256 amount) external onlyOwner {
        require(
            amount + treasuryRoyaltiesPerCurrency[currency] <= 10000,
            "Amount of both royalties must be equal to or bellow 10000 (100%)"
        );
        marketRoyaltiesPerCurrency[currency] = amount;
    }

    function setFeeManger(address manager, bool enabled) external onlyOwner {
        feeManager[manager] = enabled;
    }

    function setContractRegistry(address registry) external onlyOwner {
        contractRegistry = IContractRegistry(registry);
    }

    function collectFees(address tokenAddress, address destination) external onlyFeeManager {

        IERC20 token = IERC20(tokenAddress);
        token.transfer(destination, token.balanceOf(address(this)));

        if (address(this).balance > 0) {
            // solhint-disable-next-line
            payable(destination).transfer(address(this).balance);
        }

    }

    function destroyContract(address payable to) external override onlyOwner {
        selfdestruct(to);
    }

}
