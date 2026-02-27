// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract HeroEvents {
    event HeroMinted(uint256 indexed heroId, address indexed player, uint8 classType, uint8 rarity);
    event HeroLeveledUp(uint256 indexed heroId, uint32 oldLevel, uint32 newLevel);
    event HeroStarUpgraded(uint256 indexed heroId, uint32 oldStar, uint32 newStar);
    event HeroAttributesUpdated(uint256 indexed heroId);
}
