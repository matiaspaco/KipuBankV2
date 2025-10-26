// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title KipuNFT - NFT Contract for Rewards
 * @dev Simple ERC-721 compatible NFT for user rewards
 */
contract KipuNFT {
    string public name = "KipuBank NFT";
    string public symbol = "KBNFT";
    
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256) public balanceOf;
    
    uint256 private nextTokenId = 1;
    address public owner;
    
    /**
     * @notice Emitted when NFT is transferred
     * @param from Address sending the NFT
     * @param to Address receiving the NFT
     * @param tokenId ID of the NFT transferred
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    
    /**
     * @notice Constructor sets the owner
     */
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @notice Mint a new NFT
     * @param to Address to receive the NFT
     * @param uri Token metadata URI
     * @return tokenId ID of the minted NFT
     */
    function safeMint(address to, string memory uri) external returns (uint256) {
        require(msg.sender == owner, "Only owner can mint");
        
        uint256 tokenId = nextTokenId++;
        ownerOf[tokenId] = to;
        _tokenURIs[tokenId] = uri;
        balanceOf[to]++;
        
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }
    
    /**
     * @notice Get token URI
     * @param tokenId ID of the token
     * @return Token metadata URI
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(ownerOf[tokenId] != address(0), "Token does not exist");
        return _tokenURIs[tokenId];
    }
}