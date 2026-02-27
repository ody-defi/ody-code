// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ItemTypes} from "./ItemTypes.sol";

interface IItemCatalog {
    function getItemDef(uint256 itemId) external view returns (ItemTypes.ItemDef memory);
    function getItemBonus(uint256 itemId) external view returns (ItemTypes.ItemBonus memory);
    function exists(uint256 itemId) external view returns (bool);
}
