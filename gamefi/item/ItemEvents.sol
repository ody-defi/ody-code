// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract ItemEvents {
    event ItemDefined(uint256 indexed itemId, string symbol, uint8 itemType, uint8 rarity);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
}
