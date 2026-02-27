// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IArbitrumCompatibility {
    // Core rollup aliases
    function rollupCore() external view returns (address);
    function bridge() external view returns (address);

    // Inbox / Outbox aliases
    function inbox() external view returns (address);
    function outbox() external view returns (address);
    function sequencerInbox() external view returns (address);
    function delayedInbox() external view returns (address);

    // Gateway aliases
    function l1GatewayRouter() external view returns (address);
    function l2GatewayRouter() external view returns (address);

    // Retryable ticket aliases
    function retryableTicketHost() external view returns (address);
}
