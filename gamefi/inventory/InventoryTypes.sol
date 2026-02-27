// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library InventoryTypes {
    struct Slot {
        uint32 index;
        uint256 itemId;
        uint256 amount;
    }

    struct EquipSet {
        uint256 heroId;
        uint256 weaponItemId;
        uint256 armorItemId;
        uint256 accessoryItemId;
    }
}
