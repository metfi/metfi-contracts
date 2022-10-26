// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/IUnstakedNFTMinter.sol";
import "./interfaces/IERC2981.sol";

contract UnstakedNFTs is ILostTokenProvider, IUnstakedNFTMinter, ERC721, ERC721Enumerable, ERC721URIStorage {

    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter private _tokenIdCounter;

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant ACCOUNT_TOKEN_HASH = keccak256(abi.encodePacked('account_token'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));

    modifier onlyAccountTokens() {
        require(msg.sender == contractRegistry.getContractAddress(ACCOUNT_TOKEN_HASH));
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }
    //---------------------------------------------------------------------------

    constructor(IContractRegistry _contractRegistry) ERC721("MetFi unstaked collectibles", "uMFT") {

        contractRegistry = _contractRegistry;

        _tokenIdCounter.increment();
    }

    function mintUnstakedTokens(address to, string[] memory URLs) public onlyAccountTokens override {

        for(uint256 x = 0; x < URLs.length; x++) {

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(to, tokenId);
            _setTokenURI(tokenId, URLs[x]);
        }
    }

    function royaltyInfo(uint256, uint256 value) external view returns (address receiver, uint256 royaltyAmount){
        return (contractRegistry.getContractAddress(TREASURY_HASH), value / 10);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
    {
        return
        super.supportsInterface(interfaceId) ||
        interfaceId == type(IERC2981).interfaceId;
    }

    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

}