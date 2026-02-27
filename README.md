# ODY Mainnet Core Contract Addresses (BSC)

## Base Token Contracts

### ODY Token Contract ($ODY)
- Address: `0xe04f8DBe78eF1A5B2CfC99C8c45bd6a3DB6d1913`
- Purpose: Core ODY token, the protocol's primary asset.

### gODY Token Contract (Staking Yield Certificate)
- Address: `0x7f68B7ce5fEf65363ff61c9B98B64e1bECEa4c2f`
- Purpose: On-chain yield certificate received by users after staking ODY.

### ODYS Token Contract ($ODYS)
- Address: `0x30d81Eb0A088beB460c73411c67BE623Aff2FadF`
- Purpose: Ecosystem token in ODY dual-token coordination; users can receive airdrops after meeting eligibility requirements.

---

## Minting-Related Contracts

### EM Smart Module Minting and Command Management Contract
- Address: `0x1E4B595c2B73BAE46335e68989E291404513896C`
- Purpose: Unified authorization and control of all minting actions.
- Notes: Hardcoded in the ODY token contract; minting permissions have been renounced to the burn address.

### POL Bond and Minting Command Contract
- Address: `0x1349cb6194DD4319D11e7B77A1BAa1162f989e2E`
- Purpose: Handles LP operations for bond groups; bond purchases request minting from the EM smart module.

### RBS Market Cap Stabilization Module Contract
- Address: `0x2D67387B61a7B3d5a568bff5D7Ee45bDbdbE5479`
- Purpose: Maintains target price range and requests minting from the EM smart module when market-cap regulation is needed.

### RBS Executor Address
- Address: `0xdE1B33A729B7dBC0138E329F70995d116b3382F7`
- Purpose: Executor-only address that issues buy/sell and minting commands on behalf of the RBS module.
- Notes: Holds no assets.

---

## Staking and Rewards

### Staking Execution Contract
- Address: `0x355113bC1Ab475AbE5915AD8386D62D7D8500e62`
- Purpose: Processes user staking operations and reward accounting.

### Staking Vault Contract
- Address: `0x5f3Ef065c6fD69Aa57fc4Da039c207efc453967E`
- Purpose: Secure on-chain custody of all staked assets.

### Reward Vault Contract
- Address: `0xa1Db2ac912664019A0335Bf16b537EB0BA04000B`
- Purpose: Stores protocol rewards and performs rebase distributions.

### Reward Release and Turbine Execution Contract
- Address: `0xacBf546BC90A1DF9108a216846b6509e63CF6F7B`
- Purpose: Controls linear reward release and turbine unlock flow.

---

## Liquidity and LP Pool

### LP Pool Contract
- Address: `0x51ff488a8d0303d6be5ff51a820684484ff7b755`
- Purpose: Base ODY/USDT liquidity pool.

---

## Treasury and Buyback Flow

### ATS Treasury Multisig Contract
- Address: `0x21df31c4Ef9c86e39Ae1d5e049aaAD241E9Ae611`
- Purpose: Odyssey treasury (ATS), managed by proposal voting and multisig governance.
- Notes: On-chain open-source logic hardcodes treasury assets to only buy back ODY from the LP pool and burn it.

### ATS Treasury Executor Address
- Address: `0xad56d6d702aa65669c43bf8c80f01246b8b97d11`
- Purpose: Executor-only address for treasury buyback commands.
- Notes: Holds no assets.

### Triple Recirculation Distribution Contract
- Address: `0x0f1D4D77504db4C4b967A71af36b3E6b80889bE9`
- Purpose: Triple capital recirculation to ensure continuous LP pool funding.

Allocation Rules:
- Staking management fee: LP pool 50%, foundation 30%, co-founder node 10%, reward pool 10%
- Claim burn fee: LP pool 40%, foundation 30%, co-founder node 15%, reward pool 15%
- Trading fee: LP pool 1%, foundation 1%, co-founder node 0.5%, reward pool 0.5%

### Triple Recirculation Executor Address
- Address: `0x26adb00c00632bf1158e17f85e237c81f441db73`
- Purpose: Executor-only address for triple recirculation distribution commands.
- Notes: Holds no assets.

### Position Yield Claim Burn-Fee Contract
- Address: `0x68142F07FbF2D56881e9658B2A4aE366e49d32d0`
- Purpose: All USDT from position-yield claim burn fees is automatically used to buy back ODY from the LP pool and periodically burned to the blackhole address.

---

## Fees

### Fee Contract (3%)
- Address: `0xbA56043040f7178Ec826452e83952a1bF9cfBb8b`
- Purpose: Collects the protocol's fixed 3% fee.

---

## Market Incentives

### Co-Founder Distribution Contract
- Address: `0x74993F07e281e532732d493c9d3b7742D8441c78`
- Purpose: Co-founder reward distribution.

### Reward Pool Distribution Contract
- Address: `0xd1F74053C6F6841c4a534D2AB73202Bdc125FcC2`
- Purpose: 60% allocated to the ODYS pool, 40% allocated to the community leaderboard.
