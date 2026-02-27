// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {InventoryTypes} from "./InventoryTypes.sol";

interface IInventory {
    function getSlot(address player, uint32 slotIndex) external view returns (InventoryTypes.Slot memory);
    function getEquipSet(uint256 heroId) external view returns (InventoryTypes.EquipSet memory);
    function listSlots(address player) external view returns (InventoryTypes.Slot[] memory);
}
