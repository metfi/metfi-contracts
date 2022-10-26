// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IAccountToken.sol";
import "./interfaces/IContractRegistry.sol";
import "./interfaces/ILostTokenProvider.sol";
import "./interfaces/IUnstakedNFTMinter.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/IDestroyableContract.sol";

contract AccountToken is IAccountToken, ILostTokenProvider, ERC721, ERC721Enumerable, ERC721URIStorage, IDestroyableContract {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    struct LevelSettings {
        string url;
        string unstakedURL;
        uint256 apy;
    }

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => uint256) public accountLevels;
    mapping(uint256 => uint256) public directUplinks;
    mapping(uint256 => uint256) public directlyEnrolledMembers;
    mapping(bytes32 => uint256) private referralLinks;
    mapping(uint256 => string) private referralStrings;

    mapping(uint256 => uint256) private liquidationRequestTimes;
    mapping(uint256 => bool) public liquidatedAccounts;
    uint256 public liquidationGracePeriod = 7 days;
    uint256 public liquidationClaimPeriod = 3 days;

    uint256 public totalAPY;
    uint256 public mfiTotalMembers;
    LevelSettings[] public levelSettings;

    //----------------- Access control ------------------------------------------
    IContractRegistry contractRegistry;
    bytes32 constant ROUTER_HASH = keccak256(abi.encodePacked('router'));
    bytes32 constant TREASURY_HASH = keccak256(abi.encodePacked('treasury'));
    bytes32 constant UNSTAKED_NFTS_HASH = keccak256(abi.encodePacked('unstaked_nfts'));

    modifier onlyRouter() {
        require(msg.sender == contractRegistry.getContractAddress(ROUTER_HASH));
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == contractRegistry.getContractAddress(TREASURY_HASH));
        _;
    }

    modifier onlyRealmGuardian() {
        require(contractRegistry.isRealmGuardian(msg.sender));
        _;
    }

    constructor(IContractRegistry _contractRegistry, LevelSettings[] memory _levelSettings) ERC721("MetFi unicorn staking", "MFT") {

        contractRegistry = _contractRegistry;

        for(uint256 x = 0; x < _levelSettings.length; x++) {
            levelSettings.push(_levelSettings[x]);
        }

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        accountLevels[tokenId] = 9;
        _tokenIdCounter.increment();
        _safeMint(contractRegistry.getContractAddress(TREASURY_HASH), tokenId);
        _setTokenURI(tokenId, levelSettings[levelSettings.length - 1].url);

        totalAPY = levelSettings[levelSettings.length - 1].apy;
        mfiTotalMembers = 10;

        emit AccountCreated(contractRegistry.getContractAddress(TREASURY_HASH), tokenId, 0, 1000, "DAO");
    }

    /**
    @notice Mint new account NFT
    @param to Owner of the new NFT
    @param directUplink NFT ID of the user that enrolled the user being created
    @param level Which level NFT to create
    @param referralLink Alias for the newly created NFT
    @return New NFT ID
    */
    function createAccount(address to, uint256 directUplink, uint256 level, string calldata referralLink) public onlyRouter override returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();

        require(bytes(referralLink).length > 0, "Referral link can't be empty");

        bytes32 newReferral = keccak256(abi.encodePacked(referralLink));
        require(referralLinks[newReferral] == 0, "Referral link already used");

        //Add referral link for NFT
        referralLinks[newReferral] = tokenId;
        referralStrings[tokenId] = referralLink;

        totalAPY += levelSettings[level].apy;

        accountLevels[tokenId] = level;
        directUplinks[tokenId] = directUplink;
        directlyEnrolledMembers[directUplink]++;
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, levelSettings[level].url);

        mfiTotalMembers += level + 1;

        emit AccountCreated(to, tokenId, directUplink, levelSettings[level].apy, referralLink);

        return tokenId;
    }

    /**
    @notice Change alias of token
    @param tokenId ID of NFT to change alias for
    @param referralLink New NFT alias
    */
    function setReferralLink(uint256 tokenId, string calldata referralLink) public onlyRouter override {

        require(bytes(referralLink).length > 0, "Referral link can't be empty");

        bytes32 newReferral = keccak256(abi.encodePacked(referralLink));
        require(referralLinks[newReferral] == 0, "Referral link already used");

        delete referralLinks[keccak256(abi.encodePacked(referralStrings[tokenId]))];

        string memory oldReferralLink = referralStrings[tokenId];

        //Set referral link for NFT
        referralLinks[newReferral] = tokenId;
        referralStrings[tokenId] = referralLink;

        emit ReferralLinkChanged(tokenId, oldReferralLink, referralLink);
    }

    /**
    @notice Returns if the account was already liquidated
    @param tokenId NFT to check liquidation status for
    @return True if NFT is liquidated, false if it's not
    */
    function accountLiquidated(uint256 tokenId) public view override returns (bool) {
        return liquidatedAccounts[tokenId];
    }

    /**
    @notice Upgrade NFT parameters for specified level
    @param tokenId NFT ID to upgrade
    @param level to which to upgrade
    */
    function upgradeAccountToLevel(uint256 tokenId, uint256 level) public onlyRouter override {

        _setTokenURI(tokenId, levelSettings[level].url);

        uint256 previousLevel = accountLevels[tokenId];
        accountLevels[tokenId] = level;

        mfiTotalMembers += level - previousLevel;

        totalAPY += levelSettings[level].apy - levelSettings[previousLevel].apy;

        emit AccountUpgraded(tokenId, level, levelSettings[level].apy);
    }

    /**
    @notice Gets all NFT IDs for specific address and number of them
    @param userAddress Address for which to list NFT IDs
    @return NFTs numberOfActive User NFT IDs and total number of them
    */
    function getAddressNFTs(address userAddress) public view override returns (uint256[] memory NFTs, uint256 numberOfActive) {

        uint256 numberOfTokens = balanceOf(userAddress);

        numberOfActive = 0;
        uint256[] memory temp = new uint256[](numberOfTokens);
        for (uint256 x = 0; x < numberOfTokens; x++) {
            if (!accountLiquidated(tokenOfOwnerByIndex(userAddress, x))) {
                temp[numberOfActive] = tokenOfOwnerByIndex(userAddress, x);
                numberOfActive++;
            }
        }

        NFTs = new uint256[](numberOfActive);
        for (uint256 x = 0; x < numberOfActive; x++) {
            NFTs[x] = temp[x];
        }

        return (NFTs, numberOfActive);
    }

    /**
    @notice Get NFT liquidation status info
    @notice status - Summed up current status (NOT_REQUESTED, IN_PROGRESS, AVAILABLE)
    @notice requestTime - When the liquidation was requested
    @notice availableTime - Time after which the NFT can be redeemed
    @notice expirationTime - Time after which the redeeming is no longer possible nad liquidation needs to be restarted
    @param tokenId NFT ID
    @return info Struct with all info
    */
    function getLiquidationInfo(uint256 tokenId) public view override returns (LiquidationInfo memory info) {

        info.requestTime = liquidationRequestTimes[tokenId];
        info.availableTime = info.requestTime + liquidationGracePeriod;
        info.expirationTime = info.availableTime + liquidationClaimPeriod;

        if (info.availableTime > block.timestamp) {
            info.status = LiquidationStatus.IN_PROGRESS;
        }else if (info.expirationTime < block.timestamp) {
            info.status = LiquidationStatus.NOT_REQUESTED;
        }else {
            info.status = LiquidationStatus.AVAILABLE;
        }

        return info;
    }

    /**
    @notice Request account NFT liquidation
    @notice Depending on status it either starts liquidation or liquidates the NFT
    @param tokenId NFT ID
    @return bool if the account was liquidated in the call
    */
    function requestLiquidation(uint256 tokenId) public override onlyRouter returns (bool) {

        uint256 liquidationTimerEnd = liquidationRequestTimes[tokenId] + liquidationGracePeriod;
        uint256 liquidationTimerExpired = liquidationTimerEnd + liquidationClaimPeriod;

        if (liquidationTimerEnd > block.timestamp) {
            revert("Timer already started");
        } else if (liquidationTimerExpired < block.timestamp) {
            liquidationRequestTimes[tokenId] = block.timestamp;
            emit AccountLiquidationStarted(tokenId);
            return false;

        } else {

            uint256 accountLevel = accountLevels[tokenId];

            delete referralLinks[keccak256(abi.encodePacked(referralStrings[tokenId]))];
            delete referralStrings[tokenId];
            liquidatedAccounts[tokenId] = true;

            string[] memory URLs = new string[](accountLevel + 1);
            for(uint256 x = 0; x < URLs.length; x++) {
                URLs[x] = levelSettings[x].unstakedURL;
            }

            IUnstakedNFTMinter(contractRegistry.getContractAddress(UNSTAKED_NFTS_HASH)).mintUnstakedTokens(ownerOf(tokenId), URLs);

            _burn(tokenId);

            emit AccountLiquidated(tokenId);
            return true;
        }
    }

    /**
    @notice Liquidate account immediately
    @notice used from treasury when user claims his share if the whole system is switched into liquidation
    @param tokenId NFT ID
    */
    function liquidateAccount(uint256 tokenId) public override onlyTreasury {

        uint256 accountLevel = accountLevels[tokenId];
        string[] memory URLs = new string[](accountLevel + 1);
        for(uint256 x = 0; x < URLs.length; x++) {
            URLs[x] = levelSettings[x].unstakedURL;
        }

        IUnstakedNFTMinter(contractRegistry.getContractAddress(UNSTAKED_NFTS_HASH)).mintUnstakedTokens(ownerOf(tokenId), URLs);

        _burn(tokenId);
    }

    /**
    @notice Cancel liquidation of the account NFT
    @param tokenId NFT ID
    */
    function cancelLiquidation(uint256 tokenId) public override onlyRouter {
        liquidationRequestTimes[tokenId] = 0;
        emit AccountLiquidationCanceled(tokenId);
    }

    /**
    @notice Returns account level
    @param tokenId NFT ID
    @return level of the acount
    */
    function getAccountLevel(uint256 tokenId) public view override returns (uint256) {
        return accountLevels[tokenId];
    }

    /**
    @notice Get number of directly enrolled members under account
    @param tokenId NFT ID
    @return number of directly enrolled members
    */
    function getAccountDirectlyEnrolledMembers(uint256 tokenId) public view override returns (uint256) {
        return directlyEnrolledMembers[tokenId];
    }

    /**
    @notice Returns alias of the NFT ID
    @param tokenId NFT ID
    @return alias of NFT
    */
    function getAccountReferralLink(uint256 tokenId) public view override returns (string memory) {
        return referralStrings[tokenId];
    }

    /**
    @notice Returns owner of NFT ID
    @param tokenId NFT ID
    @return owner address of NFT
    */
    function ownerOf(uint256 tokenId) public view override(ERC721, IAccountToken) returns (address owner) {
        return super.ownerOf(tokenId);
    }

    /**
    @notice Returns NFT ID from the alias
    @param referralLink NFT Alias
    @return NFT ID behind the alias
    */
    function getAccountByReferral(string calldata referralLink) public view override returns (uint256) {
        uint256 tokenId = referralLinks[keccak256(abi.encodePacked(referralLink))];
        require(tokenId != 0, "Referral link does not exist");

        return tokenId;
    }

    /**
    @notice Check if alias exists in the system
    @param referralLink alias to check
    @return true if exists, false if it doesn't
    */
    function referralLinkExists(string calldata referralLink) public view override returns (bool) {
        return referralLinks[keccak256(abi.encodePacked(referralLink))] != 0;
    }

    /**
    @notice Returns the parent ID in selected matrix level
    @notice returns NFT IDs that were skipped because of not having high enough level
    @param nftId NFT ID
    @param nextLevel level to find parent in
    @return (new parent NFT ID, array of NFTs that were skipped)
    */
    function getLevelMatrixParent(uint256 nftId, uint256 nextLevel) public view override returns (uint256, uint256[] memory) {

        uint256 currentParent = directUplinks[nftId];
        uint256 checkNum = 0;
        uint256[] memory overtakenTmp = new uint256[](5);
        while (accountLevels[currentParent] < nextLevel) {

            overtakenTmp[checkNum] = currentParent;
            currentParent = directUplinks[currentParent];

            checkNum++;

            if (checkNum == 5) {
                currentParent = 1;
                break;
            }
        }

        uint256[] memory overtakenUsers = new uint256[](checkNum);
        for (uint256 x = 0; x < checkNum; x++) {
            overtakenUsers[x] = overtakenTmp[x];
        }

        return (currentParent, overtakenUsers);
    }

    /**
    @notice Get direct uplink NFT ID of selected token
    @param nftId NFT ID
    @return NFT ID of direct uplink
    */
    function getDirectUplink(uint256 nftId) public view override returns (uint256) {
        return directUplinks[nftId];
    }

    /**
    @notice Returns average APY based on all accounts
    @return average APT in percentage
    */
    function getAverageAPY() public view override returns (uint256) {
        return totalAPY / super.totalSupply();
    }

    /**
    @notice Returns total members of the system
    @return Number of total members
    */
    function totalMembers() public view override returns (uint256) {
        return mfiTotalMembers;
    }

    /**
    @notice Returns expected royalties on NFT purchase according to EIP 2981
    @notice 10% royalty that goes to the community
    @param value Total purchase value used for royalty calculation
    @return receiver royaltyAmount (Treasury address, Amount or royalties to pay)
    */
    function royaltyInfo(uint256, uint256 value) external view returns (address receiver, uint256 royaltyAmount){
        return (contractRegistry.getContractAddress(TREASURY_HASH), value / 10);
    }

    /**
    @notice Returns total amounts of existing NFTs
    @return Total amount
    */
    function totalSupply() public view override(ERC721Enumerable, IAccountToken) returns (uint256) {
        return super.totalSupply();
    }

    /**
    @notice Returns number of NFTs that a specific wallet owns
    @param owner address
    @return balance Number of NFTs
    */
    function balanceOf(address owner) public view override(ERC721, IAccountToken) returns (uint256 balance) {
        return super.balanceOf(owner);
    }

    /**
    @notice Used for ERC721 enumeration over users tokens
    @param owner address
    @param index of the token to get ID for
    @return ID of the user token at index
    */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override(ERC721Enumerable, IAccountToken) returns (uint256) {
        return super.tokenOfOwnerByIndex(owner, index);
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

    /**
    @notice URL for the JSON file with NFT metadata
    @param tokenId NFT ID
    @return URI with metadata
    */
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

    /**
    @notice Function to send ERC20 compatible token to treasury
    @notice used fo collecting tokens that shouldn't be in the contract
    @param tokenAddress Address of the token to collect
    */
    function getLostTokens(address tokenAddress) public override onlyTreasury {

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    /**
    @notice Destroy the contract when the liquidation of the system is finished and all users have claimed their share
    @param to Where to send excess value
    */
    function destroyContract(address payable to) public override onlyTreasury {
        selfdestruct(to);
    }

    /**
    @notice Change time needed to do the liquidation
    @param newLiquidationGracePeriod Time needed to allow liquidation
    @param newLiquidationClaimPeriod Time in which the NFT can be liquidated
    */
    function setLiquidationPeriods(uint256 newLiquidationGracePeriod, uint256 newLiquidationClaimPeriod) public onlyRealmGuardian {
        liquidationGracePeriod = newLiquidationGracePeriod;
        liquidationClaimPeriod = newLiquidationClaimPeriod;
    }
}