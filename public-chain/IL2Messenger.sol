// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {L2Types} from "./L2Types.sol";

interface IL2Messenger {
    function sendMessage(L2Types.L2Message calldata message) external returns (bytes32 msgId);
    function relayMessage(L2Types.L2Message calldata message) external;
    function messageStatus(bytes32 msgId) external view returns (L2Types.MessageStatus);
    function messageNonce(address sender) external view returns (uint256);
}
