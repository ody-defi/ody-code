// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library L2StorageKeys {
    bytes32 internal constant ROLLUP_NAMESPACE = keccak256("ody.l2.rollup.storage.v1");
    bytes32 internal constant MESSENGER_NAMESPACE = keccak256("ody.l2.messenger.storage.v1");
    bytes32 internal constant BRIDGE_NAMESPACE = keccak256("ody.l2.bridge.storage.v1");
    bytes32 internal constant TOKEN_GATEWAY_NAMESPACE = keccak256("ody.l2.gateway.storage.v1");
    bytes32 internal constant SEQUENCER_NAMESPACE = keccak256("ody.l2.sequencer.storage.v1");
    bytes32 internal constant FEE_NAMESPACE = keccak256("ody.l2.fee.storage.v1");
}
