// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract MembershipNFT is ERC721URIStorage, Ownable {
    using Strings for uint256;
    
    uint256 private _nextTokenId;
    
    struct Party {
        string name;
        uint256 joinFee;
        uint256 memberCount;
        uint256 totalContributions;
    }
    
    mapping(uint256 => Party) public parties;
    mapping(uint256 => mapping(address => bool)) public partyMembers;
    mapping(address => mapping(uint256 => uint256)) public memberTokens;
    mapping(uint256 => uint256) public tokenToParty;
    mapping(uint256 => uint256) public tokenIdToLevels;
    uint256 public partyCount;
    
    constructor() ERC721("Membership NFT", "MNFT") Ownable(msg.sender) {}
    
    function createParty(string memory _name, uint256 _fee) public onlyOwner {
        uint256 partyId = partyCount;
        parties[partyId] = Party({
            name: _name,
            joinFee: _fee,
            totalContributions: 0,
            memberCount: 0
        });
        partyCount++;
    }
    
    function payContributionToJoinParty(uint256 partyId) public payable {
        require(partyId < partyCount, "Party does not exist");
        require(msg.value >= parties[partyId].joinFee, "Insufficient contribution to join party");
        require(!partyMembers[partyId][msg.sender], "Already a member");
        
        partyMembers[partyId][msg.sender] = true;
        parties[partyId].memberCount++;
        parties[partyId].totalContributions += msg.value;
        
        // Mint NFT
        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        memberTokens[msg.sender][partyId] = tokenId;
        tokenToParty[tokenId] = partyId;
        tokenIdToLevels[tokenId] = 0;
        
        // Set token URI
        _setTokenURI(tokenId, getTokenURI(tokenId));
    }
    
    function isMember(uint256 partyId, address user) public view returns (bool) {
        require(partyId < partyCount, "Party does not exist");
        return partyMembers[partyId][user];
    }
    
    function withdrawContributions(uint256 partyId, address payable to) public onlyOwner {
        require(partyId < partyCount, "Party does not exist");
        uint256 amount = parties[partyId].totalContributions;
        parties[partyId].totalContributions = 0;
        to.transfer(amount);
    }
    
    // NFT metadata functions
    function getLevels(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        uint256 levels = tokenIdToLevels[tokenId];
        return levels.toString();
    }
    
    function getPartyName(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        uint256 partyId = tokenToParty[tokenId];
        return parties[partyId].name;
    }
    
    function generateCharacter(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>',
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="30%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Membership NFT",
            '</text>',
            '<text x="50%" y="45%" class="base" dominant-baseline="middle" text-anchor="middle">',
            getPartyName(tokenId),
            '</text>',
            '<text x="50%" y="60%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Level: ",
            getLevels(tokenId),
            '</text>',
            '</svg>'
        );
        
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(svg)
            )
        );
    }
    
    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "Membership NFT #', tokenId.toString(), '",',
            '"description": "On-chain membership token for ', getPartyName(tokenId), '",',
            '"image": "', generateCharacter(tokenId), '"',
            '}'
        );
        
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }
    
    // function train(uint256 tokenId) public {
    //     require(_exists(tokenId), "Please use an existing token");
    //     require(ownerOf(tokenId) == msg.sender, "You must own this token to train it");
        
    //     uint256 currentLevel = tokenIdToLevels[tokenId];
    //     tokenIdToLevels[tokenId] = currentLevel + 1;
    //     _setTokenURI(tokenId, getTokenURI(tokenId));
    // }
    
    // Check if a token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}