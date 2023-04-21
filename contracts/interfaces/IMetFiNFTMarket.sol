// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;


interface IMetFiNFTMarket {
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

    function buyNFT(ListingData calldata listingData, address paymentCurrency) external;

    function revokeListing(ListingData calldata listingData) external;

    function isListingRevoked(bytes32 listingHash) external view returns (bool);

    function getTotalRoyaltiesForCurrency(address currency) external view returns (uint256, uint256, uint256);

}
