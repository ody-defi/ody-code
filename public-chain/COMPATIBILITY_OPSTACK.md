# OP Stack Compatibility Mapping

This document maps the current ETH L2 scaffold naming to common OP Stack style terms.

## Contract Domain Mapping

| This Scaffold | OP Stack Style | Notes |
| --- | --- | --- |
| `IRollupCore` | `SystemConfig` + chain-level state refs | Chain config and batch status view surface. |
| `IBatchManager` | `L2OutputOracle` + proposal/finalization controls | Batch lifecycle abstraction. |
| `IL2Messenger` | `L1CrossDomainMessenger` / `L2CrossDomainMessenger` | Generic cross-domain message envelope. |
| `IBridgeHub` | `OptimismPortal` + bridge entry points | Deposit/withdraw flow envelope. |
| `ITokenGateway` | `L1StandardBridge` / `L2StandardBridge` token mapping | Token pair registry and status. |
| `ISequencerSet` | `SystemConfig` sequencer fields | Sequencer rotation and epoch metadata. |
| `IFeeVault` | `BaseFeeVault` / `L1FeeVault` style settlement vaults | Unified fee settlement abstraction. |

## Event Mapping

| This Scaffold Event | OP Stack Style Event | Notes |
| --- | --- | --- |
| `MessageSent` | `SentMessage` | Message emission from source domain. |
| `MessageRelayed` | `RelayedMessage` | Relay execution completion. |
| `WithdrawalInitiated` | `MessagePassed` / withdrawal initiated flow | L2 -> L1 intent stage. |
| `WithdrawalFinalized` | Finalized withdrawal / relay success | L1 completion stage. |
| `BatchProposed` | output proposal submitted | Batch/post-state proposal stage. |
| `BatchFinalized` | output proposal finalized | Post challenge-window finality. |

## Type Mapping

| This Scaffold Type | OP Stack Style Concept | Notes |
| --- | --- | --- |
| `L2Types.BatchHeader` | output root proposal payload | Header-oriented batch view. |
| `L2Types.BatchProof` | fault/zk proof envelope | Proof payload abstraction. |
| `L2Types.L2Message` | xDomain calldata package | Sender/target/value/gas/data shape. |
| `L2Types.Withdrawal` | withdrawal transaction envelope | Cross-domain exit payload. |
| `L2Types.TokenPair` | canonical token pair mapping | L1/L2 token correspondence. |

## Compatibility Notes

1. This scaffold stays implementation-agnostic and can map to OP Stack, Arbitrum-style, or ZK rollup internals.
2. Final production naming can keep current names while exposing compatibility aliases in adapter contracts.
3. Interface IDs can be frozen per module once implementation architecture is selected.
