// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./interfaces/IERC2981.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IMetFiNFTMarketV2.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IDestroyableContract.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


contract MetFiNFTMarketV2 is IMetFiNFTMarketV2, IDestroyableContract, EIP712 {

    using SafeERC20 for IERC20;
    using Address for address payable;

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

    modifier onlyRealmGuardian() {
        require(contractRegistry.isRealmGuardian(msg.sender));
        _;
    }

    modifier checkListingData(ListingData calldata listingData, address paymentCurrency) {
        {// Wrapped to avoid stack too deep error
            require(block.timestamp <= listingData.deadline, "Listing expired");

            bytes32 listingHash = getListingDataHash(listingData);

            require(!invalidatedListingHashes[listingHash], "Listing revoked");

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
    address public selectedStableCoin;


    mapping(address => bool) internal paymentCurrencies;
    mapping(address => uint256) marketRoyaltiesPerCurrency;
    mapping(address => uint256) treasuryRoyaltiesPerCurrency;

    mapping(bytes32 => bool) internal invalidatedListingHashes;

    constructor(IContractRegistry _contractRegistry, address _selectedStableCoin) EIP712 ("MetFiNFTMarket", "1") {
        require(address(_contractRegistry) != address(0), "Invalid contract registry address");
        require(_selectedStableCoin != address(0), "Invalid stablecoin address");
        contractRegistry = _contractRegistry;
        pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        selectedStableCoin = _selectedStableCoin;
        treasuryRoyaltiesPerCurrency[_selectedStableCoin] = 1000;
        paymentCurrencies[_selectedStableCoin] = true;

        address mfiAddress = contractRegistry.getContractAddress(MFI_HASH);
        treasuryRoyaltiesPerCurrency[mfiAddress] = 1000;
        paymentCurrencies[mfiAddress] = true;
    }


    function buyNFT(ListingData calldata listingData, address paymentCurrency, uint256 amountInMax, uint256 treasuryRoyaltiesMin)
    override
    external
    checkListingData(listingData, paymentCurrency) {

        // Check balances and allowances, convert payment currency if needed, calculate royalties and transfer funds
        checkAndTransferFunds(listingData, paymentCurrency, amountInMax, treasuryRoyaltiesMin);

        // Prevent replay attacks and reentrancy
        invalidatedListingHashes[getListingDataHash(listingData)] = true;

        // Transfer NFT to new Owner
        IERC721(contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH)).safeTransferFrom(
            listingData.tokenOwner,
            msg.sender,
            listingData.tokenId
        );

        emit NFTSold(listingData.tokenId, paymentCurrency, listingData.amount);

    }

    function checkAndTransferFunds(ListingData calldata listingData, address paymentCurrency, uint256 amountInMax, uint256 treasuryRoyaltiesMin) private {

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
                    transferRoyaltiesToTreasury(royaltyAmount, listingData.currency, treasuryRoyaltiesMin);
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
                amountInMax,
                path,
                address(this),
                block.timestamp + 60);

            IERC20(listingData.currency).safeTransfer(listingData.tokenOwner, amountReceived);

            if (royaltyAmount > 0) {
                transferRoyaltiesToTreasury(royaltyAmount, listingData.currency, treasuryRoyaltiesMin);
            }

        }
        if (marketFee > 0) {
            emit MarketRoyaltyFeePaid(listingData.currency, marketFee);
        }
    }

    function calculatePurchaseValues(ListingData calldata listingData, address paymentCurrency) override external view returns (uint256 maxAmountIn) {

        uint256 amountInListingCurrency =
        (listingData.amount * (10 ** IERC20Metadata(listingData.currency).decimals())) / 10000;

        address[] memory path = new address[](2);
        path[0] = paymentCurrency;
        path[1] = listingData.currency;

        maxAmountIn = pancakeRouter.getAmountsIn(amountInListingCurrency, path)[0];
    }

    function transferRoyaltiesToTreasury(uint256 amount, address currency, uint256 treasuryRoyaltiesMin) internal {
        address treasury = contractRegistry.getContractAddress(TREASURY_HASH);

        if (currency == contractRegistry.getContractAddress(MFI_HASH)) {
            address[] memory path = new address[](2);
            path[0] = currency;
            path[1] = selectedStableCoin;

            IERC20(currency).safeApprove(address(pancakeRouter), amount);

            uint[] memory swappedAmounts = pancakeRouter.swapExactTokensForTokens(
                amount,
                treasuryRoyaltiesMin,
                path,
                treasury,
                block.timestamp + 60);
            emit TreasuryRoyaltyFeePaid(selectedStableCoin, swappedAmounts[1]);

        } else {
            IERC20(currency).safeTransfer(treasury, amount);
            emit TreasuryRoyaltyFeePaid(currency, amount);
        }

    }

    function revokeListing(ListingData calldata listingData) override external {

        bytes32 listingHash = getListingDataHash(listingData);
        require(!invalidatedListingHashes[listingHash], "Listing already revoked");

        address seller = ECDSA.recover(listingHash, listingData.signature);
        require(seller == listingData.tokenOwner, "Bad listing request");

        require(msg.sender == seller, "Only the seller can revoke his listing");

        invalidatedListingHashes[listingHash] = true;

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
        return invalidatedListingHashes[listingHash];
    }

    function getTotalRoyaltiesForCurrency(address currency) override external view returns (uint256, uint256, uint256) {
        require(paymentCurrencies[currency], "Currency not supported");
        return (
        treasuryRoyaltiesPerCurrency[currency] + marketRoyaltiesPerCurrency[currency],
        marketRoyaltiesPerCurrency[currency],
        treasuryRoyaltiesPerCurrency[currency]);
    }

    function setPaymentCurrency(address currency, bool enabled, uint256 marketRoyalties, uint256 treasuryRoyalties) external onlyRealmGuardian {
        require(currency != address(0), "Currency address cannot be 0");
        require(marketRoyalties + treasuryRoyalties <= 10000, "Amount of both royalties must be equal to or bellow 10000 (100%)");
        require(currency != selectedStableCoin && !enabled, "Cannot disable selected stable coin");
        marketRoyaltiesPerCurrency[currency] = marketRoyalties;
        treasuryRoyaltiesPerCurrency[currency] = treasuryRoyalties;
        paymentCurrencies[currency] = enabled;
    }

    function setFeeManger(address manager, bool enabled) external onlyRealmGuardian {
        feeManager[manager] = enabled;
    }

    function setContractRegistry(address registry) external onlyRealmGuardian {
        contractRegistry = IContractRegistry(registry);
    }

    function collectFees(address tokenAddress, address payable destination) external onlyFeeManager {

        require(tokenAddress != address(0), "Token address cannot be 0x0");
        require(destination != address(0), "Destination address cannot be 0x0");

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(destination, token.balanceOf(address(this)));

        if (address(this).balance > 0) {
            // solhint-disable-next-line
            destination.sendValue(address(this).balance);
        }

    }

    function setSelectedStableCoin(address stablecoin) external onlyRealmGuardian {
        require(stablecoin != address(0), "Stablecoin address cannot be 0x0");
        require(paymentCurrencies[stablecoin], "Stablecoin must be a payment currency");

        selectedStableCoin = stablecoin;
    }

    function destroyContract(address payable to) external override onlyRealmGuardian {
        selfdestruct(to);
    }

}
