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

contract SocalSale is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    event UpdateNftOwner(uint256 tokenId, address prevOwner, address newOwner, bool status, uint256 time);
    event WhitelistingNft(
        address tokenAddress,
        address owner,
        uint256 tokenId,
        uint256 price,
        bool status,
        uint256 time
    );
    event RemoveNft(address owner, uint256 tokenId);

    Counters.Counter private _tokenIdTracker;
    address public primaryToken;
    address public protocolToken;

    address public wallet = 0xdD15D2650387Fb6FEDE27ae7392C402a393F8A37;

    uint256 public MAX_SUPPLY = 1511;
    uint256 public finalMintAmount = 1550;
    uint256 public PRICE = 0.2 ether;

    bool public openPresale = false;
    uint256 public constant MAX_PER_MINT = 20;

    mapping(address => uint256) public presaleMintAmount;
    mapping(uint256 => uint256) public tokenIdToPrice;

    string public baseTokenURI;
    string public mdata;

    constructor(
        string memory baseURI,
        address primaryToken_,
        address protocolToken_,
        string memory mdata_
    ) ERC721("Socal Mystery", "SM") {
        setBaseURI(baseURI);
        primaryToken = primaryToken_;
        protocolToken = protocolToken_;
        mdata = mdata_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, mdata, tokenId.toString(), ".json")) : "";
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function mint(uint256 _count) public payable {
        uint256 totalMinted = _tokenIdTracker.current();
        require(totalMinted.add(_count) <= finalMintAmount, "Socalsale: Not enough NFTs!");
        require(openPresale, "Socalsale: minting is either paused or not yet opened.");

        if (openPresale && _msgSender() != owner()) {
            presaleMintAmount[_msgSender()] = presaleMintAmount[_msgSender()].add(_count);
        }

        if (_msgSender() != owner()) {
            uint256 totalPrice = PRICE.mul(_count);
            require(_count > 0 && _count <= MAX_PER_MINT, "ERROR: Cannot mint specified number of NFTs.");

            if (msg.value >= totalPrice) {
                if (_msgSender() != owner()) {
                    (bool sent, bytes memory data) = (address(this)).call{ value: msg.value }("");
                    require(sent, "Failed to send Ether");
                }
            } else {
                IERC20(primaryToken).transferFrom(_msgSender(), wallet, totalPrice);
            }
        }

        for (uint256 i = 0; i < _count; i++) {
            _mintSingleNFT();
        }
    }

    function _mintSingleNFT() private {
        _tokenIdTracker.increment();
        uint256 newTokenID = _tokenIdTracker.current();
        _safeMint(_msgSender(), newTokenID);
    }

    function addNftsForSale(uint256[] calldata tokenIds, uint256[] calldata prices) external {
        require(tokenIds.length == prices.length, "length not same");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(prices[i] > 0, "Zero amount cannot be allow");
            require(ownerOf(tokenIds[i]) == _msgSender(), "NA");
            tokenIdToPrice[tokenIds[i]] = prices[i];
            emit WhitelistingNft(address(protocolToken), msg.sender, tokenIds[i], prices[i], true, block.timestamp);
        }
    }

    function removeNftsForSale(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == _msgSender(), "NA");
            tokenIdToPrice[tokenIds[i]] = 0;
            emit RemoveNft(msg.sender, tokenIds[i]);
        }
    }

    function buyNft(uint256 tokenId) external payable {
        require(tokenIdToPrice[tokenId] > 0, "Socalsale: transfer required amount");

        require(ownerOf(tokenId) != _msgSender(), "You are the owner");

        require(IERC20(protocolToken).balanceOf(_msgSender()) >= tokenIdToPrice[tokenId]);

        IERC20(protocolToken).transferFrom(_msgSender(), ownerOf(tokenId), tokenIdToPrice[tokenId]);

        emit UpdateNftOwner(tokenId, ownerOf(tokenId), _msgSender(), false, block.timestamp);

        _transfer(ownerOf(tokenId), _msgSender(), tokenId);
        tokenIdToPrice[tokenId] = 0;
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
        IERC20(primaryToken).transfer(_msgSender(), IERC20(primaryToken).balanceOf(address(this)));
    }

    function updateToken(address newToken_, bool isPrimaryToken) public onlyOwner {
        isPrimaryToken ? primaryToken = newToken_ : protocolToken = (newToken_);
    }

    function updatePrices(uint256 newPrice) public onlyOwner {
        PRICE = newPrice;
    }

    function toggleSalestatus() public onlyOwner {
        openPresale = !openPresale;
    }

    function updateMintUpto(uint256 newMintUpto) public onlyOwner {
        require(newMintUpto <= MAX_SUPPLY, "ERROR: Can not be more than max supply");
        finalMintAmount = newMintUpto;
    }

    function updateMDataName(string memory mdata_) public onlyOwner {
        mdata = mdata_;
    }

    function updateWallet(address _newWallet) external {
        wallet = _newWallet;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
