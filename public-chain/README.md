# Public Chain (ETH L2) Definition

Standardized interface-first definition for an Ethereum Layer2 public chain.

Scope:
- protocol data types
- protocol events
- protocol interfaces
- custom errors and storage namespace keys
- no implementation logic

Suggested architecture domains:
- rollup state and batch lifecycle
- cross-domain messaging (L1 <-> L2)
- bridge and token gateway
- sequencer and fee settlement
- proof/finality and challenge window

Compatibility references:
- `COMPATIBILITY_OPSTACK.md`
- `IOpStackCompatibility.sol`
- `COMPATIBILITY_ARBITRUM.md`
- `IArbitrumCompatibility.sol`
- `COMPATIBILITY_ZKSTACK.md`
- `IZkStackCompatibility.sol`
