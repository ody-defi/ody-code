// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract EconomyEvents {
    event CurrencyChanged(address indexed player, uint8 indexed currency, int256 amount, bytes32 reasonCode, uint64 timestamp);
    event EnergyRefilled(address indexed player, uint256 oldEnergy, uint256 newEnergy, uint64 timestamp);
}
