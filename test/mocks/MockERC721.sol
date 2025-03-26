// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _tokenId = 0;
    
    constructor() ERC721("Mock NFT", "MNFT") {}
    
    function mint(address to) external returns (uint256) {
        uint256 newTokenId = _tokenId++;
        _mint(to, newTokenId);
        return newTokenId;
    }
}