//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interface/IERC165.sol";
import "./interface/IERC721.sol";
import "./interface/IERC721Metadata.sol";
import "./interface/IERC20.sol";

import "./library/SafeMath.sol";
import "./library/Counter.sol";

import "./helper/ERC721Enumerable.sol";
import "./helper/Ownable.sol";

contract MRLandSale is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;
    IERC20 public token;
    address public landSaleWallet = 0xb226f30904CE65730aD4A586d6a9171710D35583;

    uint256 public MAX_SUPPLY = 150000;
    uint256 public finalMintAmount = 1000;
    uint256 public PRICE = 1 * 10**6 * 10**18;

    bool public openPrivatesale = false;
    bool public openPresale = false;
    bool public openPublicsale = false;

    uint256 public constant MAX_PER_MINT = 20;
    mapping(address => bool) public whitelists;
    mapping(address => uint256) public privateMintAmount;
    mapping(address => uint256) public presaleMintAmount;
    string public baseTokenURI;
    string public mdata;

    constructor(
        string memory baseURI,
        IERC20 token_,
        string memory mdata_
    ) ERC721("Meta Ruffy Mystery Land", "MRML") {
        setBaseURI(baseURI);
        token = token_;
        mdata = mdata_;
        whitelists[msg.sender] = true;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, mdata, ".json")) : "";
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function mint(uint256 _count) public payable {
        uint256 totalMinted = _tokenIdTracker.current();
        require(totalMinted.add(_count) <= finalMintAmount, "Landsale: Not enough NFTs!");
        require(
            openPrivatesale || openPresale || openPublicsale,
            "Landsale: minting is either paused or not yet opened."
        );

        if (openPrivatesale && msg.sender != owner()) {
            require(whitelists[_msgSender()], "Landsale: wallet is not whitelisted.");
            require(
                privateMintAmount[_msgSender()].add(_count) <= MAX_PER_MINT,
                "Landsale: maximum wallet mint amount"
            );
            privateMintAmount[_msgSender()] = privateMintAmount[_msgSender()].add(_count);
        }

        if (openPresale && msg.sender != owner()) {
            presaleMintAmount[_msgSender()] = presaleMintAmount[_msgSender()].add(_count);
        }

        if (msg.sender != owner()) {
            uint256 totalPrice = PRICE.mul(_count);
            require(_count > 0 && _count <= MAX_PER_MINT, "Landsale: Cannot mint specified number of NFTs.");
            require(
                token.allowance(_msgSender(), address(this)) >= totalPrice,
                "Landsale: plase approve us to spend you MR tokens"
            );
            token.transferFrom(_msgSender(), landSaleWallet, totalPrice);
        }

        for (uint256 i = 0; i < _count; i++) {
            _mintSingleNFT();
        }
    }

    function _mintSingleNFT() private {
        _tokenIdTracker.increment();
        uint256 newTokenID = _tokenIdTracker.current();
        _safeMint(msg.sender, newTokenID);
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");
        (bool success, ) = (msg.sender).call{ value: balance }("");
        require(success, "Transfer failed.");
    }

    function claimTokens() public onlyOwner {
        token.transfer(_msgSender(), token.balanceOf(address(this)));
    }

    function updateToken(IERC20 newToken_) public onlyOwner {
        token = newToken_;
    }

    function transferNFT(uint256 tokenId, address to) public {
        safeTransferFrom(msg.sender, to, tokenId);
    }

    function updatePrices(uint256 newPrice) public onlyOwner {
        PRICE = newPrice;
    }

    function updateWhitelist(address[] memory addresses) public onlyOwner {
        for (uint256 i; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Landsale: array has a zero address.");
            whitelists[addresses[i]] = true;
        }
    }

    function addWhitelist(address newAddress) public onlyOwner {
        require(newAddress != address(0), "Landsale: whitelist address is zero.");
        whitelists[newAddress] = true;
    }

    function removeWhitelist(address newAddress) public onlyOwner {
        whitelists[newAddress] = false;
    }

    function updateOpenstatus(
        bool privateSaleStatus,
        bool preSaleStatus,
        bool publicSaleStatus
    ) public onlyOwner {
        openPrivatesale = privateSaleStatus;
        openPresale = preSaleStatus;
        openPublicsale = publicSaleStatus;
    }

    function updateMintUpto(uint256 newMintUpto) public onlyOwner {
        require(newMintUpto <= MAX_SUPPLY, "Landsale: Can not be more than max supply");
        finalMintAmount = newMintUpto;
    }

    function updateMDataName(string memory mdata_) public onlyOwner {
        mdata = mdata_;
    }
}
