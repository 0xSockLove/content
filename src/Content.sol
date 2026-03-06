// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Content
/// @author 0xSockLove
/// @notice Minimal, gas-efficient ERC1155 with owner-only minting, sequential IDs, per-token URIs and Minted event
contract Content is ERC1155, Ownable {
    uint256 private _idCounter;
    mapping(uint256 id => string uri) private _uris;

    event Minted(uint256 indexed id, uint256 amount, string uri);

    error EmptyURI();
    error ZeroAmount();

    constructor() ERC1155("") Ownable(msg.sender) {}

    /// @notice Mints a new token with the given URI and amount
    /// @param _uri Metadata URI for the token
    /// @param _amount Number of tokens to mint
    /// @return id The newly created token ID
    function mint(string calldata _uri, uint256 _amount) external onlyOwner returns (uint256 id) {
        if (bytes(_uri).length == 0) revert EmptyURI();
        if (_amount == 0) revert ZeroAmount();

        unchecked { id = ++_idCounter; }
        _uris[id] = _uri;
        _mint(msg.sender, id, _amount, "");

        emit Minted(id, _amount, _uri);
    }

    /// @notice Returns the metadata URI for a token
    /// @param _id Token ID
    /// @return Metadata URI
    function uri(uint256 _id) public view override returns (string memory) {
        return _uris[_id];
    }
}
