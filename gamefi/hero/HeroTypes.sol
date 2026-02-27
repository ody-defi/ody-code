// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library HeroTypes {
    enum HeroClass { Warrior, Ranger, Mage, Assassin, Tank, Support }
    enum HeroRarity { Common, Rare, Epic, Legendary, Mythic }

    struct HeroCore {
        uint256 heroId;
        address player;
        HeroClass classType;
        HeroRarity rarity;
        uint32 level;
        uint32 star;
    }

    struct HeroAttributes {
        uint32 hp;
        uint32 atk;
        uint32 def;
        uint32 speed;
        uint32 critRate;
        uint32 critDamage;
    }
}
