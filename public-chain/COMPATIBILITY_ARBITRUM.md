# Arbitrum Nitro Compatibility Mapping

This document maps the current ETH L2 scaffold naming to common Arbitrum Nitro style terms.

## Contract Domain Mapping

| This Scaffold | Arbitrum Nitro Style | Notes |
| --- | --- | --- |
| `IRollupCore` | `RollupCore` / rollup state refs | Chain config and batch/assertion status view surface. |
| `IBatchManager` | assertion lifecycle manager | Batch/assertion propose-confirm-revert abstraction. |
| `IL2Messenger` | `Inbox` / `Outbox` message flow envelope | Generic cross-domain message relay abstraction. |
| `IBridgeHub` | `Bridge` + retryable ticket entry points | Deposit/withdraw envelope. |
| `ITokenGateway` | `L1GatewayRouter` / `L2GatewayRouter` + gateways | Canonical token mapping and status. |
| `ISequencerSet` | sequencer / delayed inbox governance refs | Sequencer rotation metadata abstraction. |
| `IFeeVault` | fee recipient / network fee accounting vault | Unified fee settlement abstraction. |

## Event Mapping

| This Scaffold Event | Arbitrum Nitro Style Event | Notes |
| --- | --- | --- |
| `MessageSent` | inbox message delivered / ticket created | Source-domain enqueue stage. |
| `MessageRelayed` | outbox execution / retryable redeemed | Relay execution completion. |
| `WithdrawalInitiated` | L2 -> L1 outbox entry created | Exit initiation stage. |
| `WithdrawalFinalized` | outbox execution success | L1 completion stage. |
| `BatchProposed` | assertion/batch proposed | State transition proposal stage. |
| `BatchFinalized` | assertion confirmed | Finalized state transition stage. |

## Type Mapping

| This Scaffold Type | Arbitrum Nitro Style Concept | Notes |
| --- | --- | --- |
| `L2Types.BatchHeader` | assertion / batch metadata | Header-oriented assertion view. |
| `L2Types.BatchProof` | fraud/validity proof envelope | Proof payload abstraction. |
| `L2Types.L2Message` | inbox/outbox message payload | Sender/target/value/gas/data shape. |
| `L2Types.Withdrawal` | outbox withdrawal envelope | Cross-domain exit payload. |
| `L2Types.TokenPair` | gateway token pair mapping | L1/L2 token correspondence. |

## Compatibility Notes

1. This scaffold is implementation-agnostic and can be adapted to Nitro contracts through alias adapters.
2. Production systems can keep native naming and expose compatibility views via facade contracts.
3. Interface IDs should be frozen only after final bridge/rollup stack selection.
