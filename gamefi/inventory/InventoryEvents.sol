// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract InventoryEvents {
    event InventorySlotUpdated(address indexed player, uint32 indexed slotIndex, uint256 itemId, uint256 amount);
    event ItemEquipped(address indexed player, uint256 indexed heroId, uint256 indexed itemId);
    event ItemUnequipped(address indexed player, uint256 indexed heroId, uint256 indexed itemId);
}
