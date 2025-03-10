// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MembershipNFT} from "./NFT.sol";

contract Contribution {

    struct Party {
        string name;
        uint256 joinFee;
        bool active;
        mapping(address => bool) members;
        uint256 memberCount;
    }

    mapping(uint => Party) public parties;
    uint public partyCount;
    MembershipNFT public nft;

    constructor(address nftAddress) {
        nft = MembershipNFT(nftAddress);
    }
}
