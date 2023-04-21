// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;


interface IMetFiNFTMarketV2 {
    event NFTListingRevoked(uint256 indexed nftId, bytes32 listingHash);

    event MarketRoyaltyFeePaid(address currency, uint256 amount);
    event TreasuryRoyaltyFeePaid(address currency, uint256 amount);
    event NFTSold(uint256 indexed nftId, address currency, uint256 amount);

    struct ListingData {
        uint256 tokenId;
        uint256 listingNonce;
        address tokenOwner;
        address currency;
        uint256 amount;
        uint256 deadline;
        bytes signature;
    }

    function buyNFT(ListingData calldata listingData, address paymentCurrency, uint256 amountInMax, uint256 treasuryRoyaltiesMin) external;

    function revokeListing(ListingData calldata listingData) external;

    function isListingRevoked(bytes32 listingHash) external view returns (bool);

    function calculatePurchaseValues(ListingData calldata listingData, address paymentCurrency) external view returns (uint256 maxAmountIn);

    function getTotalRoyaltiesForCurrency(address currency) external view returns (uint256, uint256, uint256);

}
