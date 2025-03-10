// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';

contract MembershipWithNFT is Ownable {
    using Strings for uint256;
    
   
    struct Party {
        string name;
        uint256 joinFee;
        uint256 memberCount;
        uint256 totalContributions;
    }
    
    mapping(uint256 => Party) public parties;
    mapping(uint256 => mapping(address => bool)) public partyMembers;
    mapping(address => mapping(uint256 => uint256)) public memberTokens;
    uint256 public partyCount;
    

    uint256 private _nextTokenId;
    
   
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    
    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    
    constructor() Ownable(msg.sender) {}
    
 
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
        require(msg.value >= parties[partyId].joinFee, "Insufficient contribution");
        require(!partyMembers[partyId][msg.sender], "Already a member");
        
        partyMembers[partyId][msg.sender] = true;
        parties[partyId].memberCount++;
        parties[partyId].totalContributions += msg.value;
        
        // Mint NFT
        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
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
    
    // ===== Minimal NFT Implementation =====
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Invalid token ID");
        return owner;
    }
    
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "Address zero query");
        return _balances[owner];
    }
    
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "Mint to zero address");
        require(_owners[tokenId] == address(0), "Token already minted");
        
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(address(0), to, tokenId);
    }
    
    // Simplified token URI generation
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "Invalid token ID");
        
        string memory tokenIdStr = tokenId.toString();
        
        // Simple SVG generation directly inline
        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300">',
            '<rect width="100%" height="100%" fill="#1a2a6c"/>',
            '<text x="150" y="150" font-family="Arial" font-size="24" text-anchor="middle" fill="white">KMS #',
            tokenIdStr,
            '</text>',
            '</svg>'
        ));
        
        // Base64 encoding implementation
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64 = _encode(bytes(svg));
        
        // Simple JSON metadata
        string memory json = string(abi.encodePacked(
            '{"name":"KMS #',
            tokenIdStr,
            '","description":"Membership Token","image":"',
            baseURL,
            svgBase64,
            '"}'
        ));
        
        return string(abi.encodePacked('data:application/json;base64,', _encode(bytes(json))));
    }
    
    // Simple base64 encoding function (replaces the OpenZeppelin Base64 library)
    function _encode(bytes memory data) internal pure returns (string memory) {
        string memory table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        
        if (data.length == 0) return '';
        
        // Calculate output length
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        
        // Add padding for data that are not divisible by 3
        bytes memory result = new bytes(encodedLen);
        
        uint256 i;
        uint256 j = 0;
        
        for (i = 0; i < data.length - 2; i += 3) {
            uint256 val = uint256(uint8(data[i])) << 16 | uint256(uint8(data[i + 1])) << 8 | uint256(uint8(data[i + 2]));
            
            result[j++] = bytes1(bytes(table)[uint8((val >> 18) & 0x3F)]);
            result[j++] = bytes1(bytes(table)[uint8((val >> 12) & 0x3F)]);
            result[j++] = bytes1(bytes(table)[uint8((val >> 6) & 0x3F)]);
            result[j++] = bytes1(bytes(table)[uint8(val & 0x3F)]);
        }
        
        if (i < data.length) {
            uint256 val = uint256(uint8(data[i])) << 16;
            if (i + 1 < data.length) val |= uint256(uint8(data[i + 1])) << 8;
            
            result[j++] = bytes1(bytes(table)[uint8((val >> 18) & 0x3F)]);
            result[j++] = bytes1(bytes(table)[uint8((val >> 12) & 0x3F)]);
            
            if (i + 1 < data.length) {
                result[j++] = bytes1(bytes(table)[uint8((val >> 6) & 0x3F)]);
                result[j++] = '=';
            } else {
                result[j++] = '=';
                result[j++] = '=';
            }
        }
        
        return string(result);
    }
}