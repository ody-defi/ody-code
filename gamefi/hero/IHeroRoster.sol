// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HeroTypes} from "./HeroTypes.sol";

interface IHeroRoster {
    function getHeroCore(uint256 heroId) external view returns (HeroTypes.HeroCore memory);
    function getHeroAttributes(uint256 heroId) external view returns (HeroTypes.HeroAttributes memory);
    function listPlayerHeroes(address player) external view returns (uint256[] memory heroIds);
}
