// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract ODYMinterEvents {
    event Minted(address indexed caller, address indexed to, uint256 amount);
    event Burned(address indexed caller, uint256 amount);
    event OdyTokenChanged(address indexed newAddress);
    event MaxMintPerTxUpdated(uint256 maxMintPerTx);
    event AllowanceEnabledUpdated(bool enabled);
    event MintAllowanceUpdated(address indexed minter, uint256 allowance);
    event MintWindowUpdated(uint256 windowSize, uint256 maxPerWindow);
}
