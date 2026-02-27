// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract MaintenanceFeeVaultEvents {
    event FeePaid(bytes32 indexed requestId, address indexed payer, uint256 amount, uint256 deadline, uint8 feeType);
    event Distributed(
        address indexed caller,
        uint256 usdtForBuy,
        uint256 odyBought,
        uint256 usdtForLp,
        uint256 lpOdyUsed,
        uint256 lpUsdtUsed,
        uint256 foundationUsdt,
        uint256 nodeUsdt,
        uint256 leaderboardUsdt
    );
    event SignerUpdated(address indexed signer, bool allowed);
    event PathUpdated(address[] newPath);
    event AddressesUpdated(address lpReceiver, address foundation, address nodeAddr, address leaderboard);
    event PortionsUpdated(uint256 lpBuy, uint256 lpUsdt, uint256 foundation, uint256 node, uint256 leaderboard);
    event UsdtWithdrawn(address indexed to, uint256 amount, address indexed caller);
}
