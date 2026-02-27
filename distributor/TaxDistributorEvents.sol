// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract TaxDistributorEvents {
    event Distributed(
        address indexed caller,
        uint256 tokenSold,
        uint256 tokenToLp,
        uint256 usdtOut,
        uint256 lpUsdt,
        uint256 foundationUsdt,
        uint256 genesisUsdt,
        uint256 leaderboardUsdt
    );
    event RouterUpdated(address indexed router);
    event OdyUpdated(address indexed ody);
    event UsdtUpdated(address indexed usdt);
    event SellPathUpdated(address[] sellPath);
    event FoundationUpdated(address indexed foundation);
    event GenesisUpdated(address indexed genesis);
    event LeaderboardUpdated(address indexed leaderboard);
    event LpReceiverUpdated(address indexed lpReceiver);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);
}
