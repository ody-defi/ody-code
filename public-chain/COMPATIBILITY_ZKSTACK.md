# ZK Stack / zkSync Compatibility Mapping

This document maps the current ETH L2 scaffold naming to common ZK Stack / zkSync style terms.

## Contract Domain Mapping

| This Scaffold | ZK Stack / zkSync Style | Notes |
| --- | --- | --- |
| `IRollupCore` | chain state manager / Diamond proxy views | Chain config and batch/state status abstraction. |
| `IBatchManager` | commit/prove/execute pipeline manager | Batch lifecycle under zk proof flow. |
| `IL2Messenger` | L1 <-> L2 messenger mailbox abstraction | Generic cross-domain envelope. |
| `IBridgeHub` | `Bridgehub` + shared bridge entrypoints | Deposit/withdraw envelope. |
| `ITokenGateway` | shared bridge token routing / asset routers | Canonical token pair mapping abstraction. |
| `ISequencerSet` | operator/sequencer role set | Sequencer/operator epoch metadata abstraction. |
| `IFeeVault` | fee collection / settlement recipient | Unified fee settlement abstraction. |

## Event Mapping

| This Scaffold Event | ZK Stack / zkSync Style Event | Notes |
| --- | --- | --- |
| `MessageSent` | L2->L1 log/message emission | Source-domain enqueue stage. |
| `MessageRelayed` | proof-backed relay execution | Relay completion stage. |
| `WithdrawalInitiated` | bridge withdrawal initiated | Exit initiation stage. |
| `WithdrawalFinalized` | withdrawal finalized on destination | Completion stage. |
| `BatchProposed` | batch committed | Commit stage. |
| `BatchProven` | batch verified | Proof verification stage. |
| `BatchFinalized` | batch executed/finalized | Final execution stage. |

## Type Mapping

| This Scaffold Type | ZK Stack / zkSync Concept | Notes |
| --- | --- | --- |
| `L2Types.BatchHeader` | committed batch metadata | Header-oriented batch view. |
| `L2Types.BatchProof` | zk proof envelope | Validity proof payload abstraction. |
| `L2Types.L2Message` | mailbox message payload | Sender/target/value/gas/data shape. |
| `L2Types.Withdrawal` | withdrawal log envelope | Cross-domain exit payload. |
| `L2Types.TokenPair` | L1/L2 token mapping tuple | Canonical token correspondence. |

## Compatibility Notes

1. This scaffold stays stack-agnostic; ZK adapters can expose these aliases without changing core naming.
2. Final production can preserve native contract naming and provide compatibility facade contracts.
3. Proof semantics may differ by implementation; only envelope fields are standardized here.
