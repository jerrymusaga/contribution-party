// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from '@openzeppelin/contracts/utils/Base64.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

contract MembershipContribution is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    using Strings for uint256;
    
    // Party structure
    struct Party {
        string name;
        uint256 joinFee;
        uint256 memberCount;
        uint256 totalContributions;
    }
    
    // Party mappings
    mapping(uint => Party) public parties;
    mapping(uint256 => mapping(address => bool)) public partyMembers;
    mapping(address => mapping(uint256 => uint256)) public memberTokens;
    uint public partyCount;
    
    constructor()
        ERC721("MembershipNFT", "MNFT")
        Ownable(msg.sender)
    {}
    
    // Party management functions
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
        
        // Mint NFT directly instead of calling another contract
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        memberTokens[msg.sender][partyId] = tokenId;
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
    
    // NFT functions
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        if (!_exists(tokenId)) {
            revert("ERC721: URI query for nonexistent token");
        }
        
        string memory storedURI = super.tokenURI(tokenId);
        
        if (bytes(storedURI).length > 0) {
            return storedURI;
        }
        
        // Generate on-chain token URI
        string memory name = string(abi.encodePacked('KemsguyNFT #', tokenId.toString()));
        string memory description = 'This is an on-chain NFT';
        string memory image = generateBase64Image(tokenId);
        string memory json = string(
            abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"',
            description,
            '",',
            '"image":"',
            image,
            '"}'
        )
        );
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(bytes(json))));
    }

    function generateBase64Image(uint256 tokenId) internal pure returns (string memory) {
        string memory tokenText = string(abi.encodePacked('KMS FIGHTER #', tokenId.toString()));
        
        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">',
            '<defs>',
            '<linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" stop-color="#1a2a6c"/>',
            '<stop offset="50%" stop-color="#b21f1f"/>',
            '<stop offset="100%" stop-color="#fdbb2d"/>',
            '</linearGradient>',
            '<filter id="glow" x="-20%" y="-20%" width="140%" height="140%">',
            '<feGaussianBlur stdDeviation="5" result="blur"/>',
            '<feComposite in="SourceGraphic" in2="blur" operator="over"/>',
            '</filter>',
            '</defs>',
            '<rect width="100%" height="100%" rx="15" ry="15" fill="url(#bgGradient)"/>',
            '<circle cx="250" cy="150" r="40" fill="#000000" stroke="#ffffff" stroke-width="2"/>',
            '<path d="M230 190 L220 300 L280 300 L270 190" fill="#000000" stroke="#ffffff" stroke-width="2"/>',
            '<path d="M230 200 L180 230 L190 250 L230 220" fill="#000000" stroke="#ffffff" stroke-width="2"/>',
            '<path d="M270 200 L330 180 L335 200 L270 220" fill="#000000" stroke="#ffffff" stroke-width="2"/>',
            '<path d="M230 300 L210 380 L240 380 L250 300" fill="#000000" stroke="#ffffff" stroke-width="2"/>',
            '<path d="M270 300 L290 380 L260 380 L250 300" fill="#000000" stroke="#ffffff" stroke-width="2"/>',
            '<circle cx="180" cy="230" r="15" fill="#ff0000" stroke="#ffffff" stroke-width="2"/>',
            '<circle cx="335" cy="200" r="15" fill="#ff0000" stroke="#ffffff" stroke-width="2"/>',
            '<text x="250" y="430" font-family="Impact, sans-serif" font-size="40" text-anchor="middle" fill="#ffffff" filter="url(#glow)">Jerry NFT</text>',
            '<path d="M100 50 L120 70 L100 90 L80 70 Z" fill="#ffcc00" stroke="#ffffff" stroke-width="1"/>',
            '<path d="M400 50 L420 70 L400 90 L380 70 Z" fill="#ffcc00" stroke="#ffffff" stroke-width="1"/>',
            '<rect x="150" y="50" width="200" height="40" rx="10" ry="10" fill="rgba(255,255,255,0.2)" stroke="#ffffff" stroke-width="1"/>',
            '<text x="250" y="77" font-family="Arial, sans-serif" font-size="20" text-anchor="middle" fill="#ffffff">',
            tokenText,
            '</text>',
            '</svg>'
        ));
        
        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(bytes(svg))));
    }
    
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    // Override required by Solidity when inheriting from multiple contracts
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}