// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library ItemTypes {
    enum ItemType { Weapon, Armor, Accessory, Material, Consumable, Key }
    enum ItemRarity { Common, Rare, Epic, Legendary }

    struct ItemDef {
        uint256 itemId;
        string symbol;
        ItemType itemType;
        ItemRarity rarity;
        bool stackable;
        uint32 maxStack;
    }

    struct ItemBonus {
        int32 atk;
        int32 def;
        int32 hp;
        int32 speed;
        int32 critRate;
    }
}
