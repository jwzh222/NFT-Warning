// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract YangNFT is ERC721, AccessControl{

    uint256 private constant _tokenStartIndex = 1001;
    uint256 private _tokenIdTracker = _tokenStartIndex;
    using SafeMath for uint256;

    string public baseTokenURI = "ipfs://QmVNL8e2NZNVty1GLAX9enwxZT5oUKsDQSUcn8bSomQ4ya/";
    uint256 public price  = 10000000000000000; //0.01 eth
    
    uint256 private constant MAXSUPPLY = 8000;
    bytes32 private constant CFO_ROLE = keccak256("CFO_ROLE");

    constructor() ERC721("YangNFT", "YNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CFO_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view virtual override returns (string memory){
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"only admin can set BaseURI!");
        baseTokenURI = baseURI;
    }

    function setPrice(uint256 _price) public {
        require(hasRole(CFO_ROLE, msg.sender),"only CFO can set price!");
        price = _price;
    }

    function setCFO(address cfo) public {
        //require(hasRole(DEFAULT_ADMIN_ROLE,msg.sender),"only admin can set CFO");
        grantRole(CFO_ROLE, cfo);
    }

    function mint() public payable{
        require(_tokenIdTracker<MAXSUPPLY+_tokenStartIndex, "tokenIndex out of scope");
        require(msg.value >= price, "Ether value sent is not correct!");
        _safeMint(msg.sender, _tokenIdTracker);
        _tokenIdTracker = _tokenIdTracker.add(1);
    }

    function withdrawOwner() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"you are not the owner!");
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // MarketPlace
    struct Offer {
        bool isForSale;
        uint nftIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }
    struct Bid {
        bool hasBid;
        uint nftIndex;
        address bidder;
        uint value;
    }

    mapping (uint => Offer) public nftsOfferedForSale;
    mapping (uint => Bid) public nftBids;
    mapping (address => uint) public pendingWithdrawals;

    event OfferedForSale(uint indexed nftIndex, uint minValue, address indexed toAddress);
    event BidEntered(uint indexed nftIndex, uint value, address indexed fromAddress);
    event BidWithdrawn(uint indexed nftIndex, uint value, address indexed fromAddress);
    event Bought(uint indexed nftIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event NoLongerForSale(uint indexed nftIndex);

    function offerNftForSale(uint nftIndex, uint minSalePriceInWei) {
        require(msg.sender == ownerOf(nftIndex), "only owner can offer to sale");
        nftsOfferedForSale[nftIndex] = Offer(true, nftIndex, msg.sender, minSalePriceInWei, 0x0);
        OfferedForSale(nftIndex, minSalePriceInWei, 0x0);
    }

    function nftNoLongerForSale(uint nftIndex){
        require(msg.sender == ownerOf(nftIndex), "you are not the owner");
        _noLongerForSale(nftIndex);
    }

    function _noLongerForSale(uint nftIndex) private {
        punksOfferedForSale[punkIndex] = Offer(false, nftIndex, msg.sender, 0, 0x0);
        NoLongerForSale(nftIndex);
    }

    function buyNft(uint nftIndex) payable {
        Offer offer = nftsOfferedForSale[nftIndex];
        require(offer.isForSale, "nft is not for sale");
        require(msg.value >= offer.minValue, "ether is not enough");
        if (offer.onlySellTo) {
            require(msg.sender == offer.onlySellTo, "not supposed to be sold to this user");
        }
        address seller = offer.seller;
        //require(seller == ownerOf(nftIndex), "seller not longer own this nft");
        safeTransferFrom(seller, msg.sender, nftIndex);
        pendingWithdrawals[seller] += msg.value; // check the units
        Bought(nftIndex, msg.value, seller, msg.sender);
        //offer.isForSale = false;   //check here
        _noLongerForSale(nftIndex);
    }

    function withdraw(){
        uint amount = pendingWithdrawals[msg.sender];
        msg.sender.transfer(amount);
        pendingWithdrawals[msg.sender] -= amount; 
        //or pendingWithdrawals[msg.sender] = 0;
    }

    function enterBidForNft(uint nftIndex) payable {
        require(msg.sender != ownerOf(nftIndex));
        Bid existBid = nftBids[nftIndex];
        if(existBid.hasBid){
            require(msg.value > existBid.value, "price should bigger than exist bid");
            pendingWithdrawals[existBid.bidder] += existBid.value;
        } 
        nftBids[nftIndex] = Bid(true, nftIndex, msg.sender, msg.value);
        BidEntered(nftIndex, msg.value, msg.sender);
    }

    function withdrawBidForNft(uint nftIndex) {
        Bid existBid = nftBids[nftIndex];
        require(existBid.hasBid, "don't have an active bid");
        require(msg.sender == existBid.bidder, "you're not the active bidder");
        msg.sender.transfer(existBid.value);
        BidWithdrawn(nftIndex, existBid.value, existBid.bidder);
        nftBids[nftIndex] = Bid(false, nftIndex, msg.sender, 0);
        
    }

    function acceptBidForNft(uint nftIndex, uint minPrice){
        require(msg.sender == ownerOf(nftIndex), "you're not the owner");
        Bid bid = nftBids[nftIndex];
        require(bid.hasBid, "bid is deactived");
        require(bid.value >= minPrice, "bid price is not enough");

        safeTransferFrom(msg.sender, bid.bidder, nftIndex);
        pendingWithdrawals[msg.sender] += bid.value;
        nftBids[nftIndex] = Bid(false, nftIndex, bid.bidder, 0);
        Bought(nftIndex, bid.value, msg.sender, bid.bidder);
    }
}
