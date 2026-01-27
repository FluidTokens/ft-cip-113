# Smart Contract Documentation CIP-113 DEX

## Table of Contents

1. [Introduction](#introduction)
2. [Programmable Tokens CIP-113](#1-programmable-tokens-cip-113)
3. [Smart Contract Architecture](#2-smart-contract-architecture)
4. [Token Lifecycle Validators](#3-token-lifecycle-validators)
5. [DEX Integration Validators](#4-dex-integration-validators)
6. [Validator Actions and Flows](#5-validator-actions-and-flows)
7. [Security](#6-security)
8. [References](#7-references)

---

## Introduction

This project implements the first DEX on Cardano fully compatible with **programmable tokens CIP-113**, developed by **Minswap Labs** and **FluidTokens**. The documentation focuses on the smart contract architecture and its actions, essential for understanding how CIP-113 tokens are managed and integrated into the DEX.

---

## 1. Programmable Tokens CIP-113

### 1.1 What is CIP-113?

**CIP-113** (Cardano Improvement Proposal 113) introduces a standard for **programmable tokens** on Cardano. These tokens remain **permanently locked inside a smart contract** (the user's smart wallet, controlled by the `programmableLogicBase` script), ensuring that every transfer respects the programmed rules defined in the token‑specific `transferLogicScript`.

The CIP‑113 tokens must be registered in an **on‑chain registry** (implemented as a sorted linked list) that tracks the configuration of each programmable token.

**Key features:**

- Freezing of funds (blacklist)
- Whitelist for authorized addresses
- Global transfer pauses
- Custom user status
- Privileged admin actions (seizure, forced transfers) via `thirdPartyTransferLogicScript`
- Regulatory compliance (USDC/USDT)

CIP‑113 adapts the UTxO model of Cardano to programmable token concepts similar to ERC‑20 on Ethereum.

### 1.2 Key Technical Mechanisms

#### Tokens Locked in Contracts

CIP‑113 tokens **can never leave the smart contracts**. Every UTxO containing a CIP‑113 token is protected by a validator script that guarantees:

- Compliance with programmed rules
- Mandatory validation on every transfer
- Permanent control via the script

#### Linked List for Blacklist/Whitelist

**Final implementation:** a **sorted linked list on‑chain** is used to manage whitelist/blacklist:

- **On‑chain structure:** nodes of the linked list ordered lexicographically
- **Operations:** insertion/removal by spending adjacent nodes
- **Proof‑based validation:** inclusion/exclusion verified via covering node pattern
  - To prove membership: include node with `key == target`
  - To prove non‑membership: include node where `node.key < target < node.next`
- **Gas efficient:** O(1) validation, no Merkle proof computation

**Advantages vs Merkle Patricia Trie:**

- Eliminates off‑chain Merkle proof complexity
- Simpler operations and lower costs
- Deterministic on‑chain verification
- Consistent with the CIP‑113 Registry pattern (already a linked list)

#### Withdraw 0 Trick

Critical mechanism for transaction‑level validation:

- The transaction includes a **withdrawal with zero amount**
- This triggers execution of the validator script associated with the stake credential
- The script validates the entire transaction (inputs, outputs, withdrawals)
- No ADA is actually withdrawn
- Enables validation without requiring predefined datum values

### 1.3 CIP‑113 Address and Smart Wallet

#### CIP‑113 Address Derivation (Smart Wallet)

CIP‑113 addresses use the **smart wallet** pattern with:

1. **Payment credential:** `programmableLogicBase` script hash (fixed for all tokens)
2. **Stake credential:** User’s unique credential (one per user)

**Result:** each user has a unique address (smart wallet) where CIP‑113 tokens remain permanently locked under the control of the `programmableLogicBase` script, while the stake credentials identify ownership and retain stake rewards for the user.

#### Optional Whitelist/Blacklist Linked Lists

**Final implementation with Linked List:**

```aiken
pub type LinkedListNode {
  key: ByteArray,        // Address hash (28 bytes), ordering key
  next: ByteArray,       // Pointer to next node (28 bytes)
  // Optional: UserStatus, metadata, etc.
}
```

**Features:**

- Separate linked list for whitelist and blacklist
- Referenced as reference inputs during transfers (if whitelist/blacklist active in the RegistryNode)
- Proof via covering node:
  - Membership: node with `key == target`
  - Non‑membership: node with `key < target < next`
- Optional: tokens without restrictions do not require a linked list

### 1.4 Main Use Cases

#### Regulated Stablecoins (USDC/USDT)

- Regulatory compliance with freezing capability
- Blacklist for illicit addresses
- Full traceability

#### Tokenized Securities

- Transfer restrictions (whitelist for accredited investors)
- Lock‑up periods for compliance
- Pause for audit purposes

#### Real‑World Assets (RWA)

- Regulation‑compliant tokenization
- Oracle integration for verification
- Transfer control based on real‑world events

---

## 2. Smart Contract Architecture

### 2.1 Overview

The system is implemented in **Aiken v1.1.2** (Plutus V3) and divided into two modules:

**Module 1: Token Lifecycle Validators** (`validators/`)

- Handles CIP‑113 token lifecycle
- Minting/burning via `issuanceLogicScript`
- Transfers with validation via `transferLogicScript`
- Global state management (whitelist/blacklist)
- **CIP‑113 Architecture:** tokens remain at the `programmableLogicBase` script address (smart wallet) and validation occurs through the `programmableLogicGlobal` stake validator that delegates to the token‑specific logic scripts

**Module 2: DEX Integration Validators** (`dexValidators/`)

- Liquidity pools
- Swap orders
- Batching
- Factory and authentication

### 2.2 Infrastructure Component: Registry

- **On‑chain Registry:** Sorted linked list tracking all registered CIP‑113 tokens
- **RegistryNode:** each entry contains the token policy, hashes of logic scripts (`transferLogicScript`, `thirdPartyTransferLogicScript`, `issuanceLogicScript`), and optional global state NFT policy
- **Usage:** during transfers, provide proof of registration (RegistryNode as reference input) to validate that the correct logic scripts are executed

### 2.3 Dependencies

- `aiken-lang/stdlib v2.1.0`

> **Note:** Final implementation uses **linked list** instead of Merkle Patricia Trie for whitelist/blacklist, so `merkle-patricia-forestry` is not required.

---

## 3. Token Lifecycle Validators

### 3.1 Global State Validator (`account.ak`)

**Responsibility:** Manages the Global State UTxO containing shared token information (e.g., Merkle roots for whitelist/blacklist).

**Note CIP‑113:** Corresponds to the optional `globalState` concept in the CIP‑113 specification. Not all programmable tokens require a global state.

**Datum:**

```aiken
pub type Datum {
  Permissions { root_wl: Option<ByteArray>, root_bl: Option<ByteArray> }
  UserStatus { status: Option<Data>, credentials: Data }
}
```

**Redeemer Actions:**

1. **InsertWL (Insert into Whitelist Linked List)**
   - Spends previous node in the whitelist linked list
   - Creates new node with ordered position: `prev.key < new_key < prev.next`
   - Updates `next` pointer of previous node
   - Requires token owner signature
2. **InsertBL (Insert into Blacklist Linked List)**
   - Same as InsertWL but for blacklist
3. **AddStatus (Update User Status)**
   - Adds/modifies custom user status
   - Requires token owner signature

**Validations (for linked‑list operations):**

- Only the owner can modify whitelist/blacklist (`is_owner_signing`)
- Lexicographic ordering must be maintained: `prev.key < new_key < prev.next`
- Previous node is spent and recreated with updated `next`
- New node created with a unique NFT identifier
- No duplicate nodes (unique key)

### 3.2 Transfer Logic Script (`transfer.ak`)

**Responsibility:** Implements custom validation logic for user‑initiated transfers of CIP‑113 tokens.

**Note CIP‑113:** This is the `transferLogicScript` referenced in CIP‑113, executed via the "withdraw 0" pattern and invoked by the `programmableLogicGlobal` validator when tokens are spent from the smart wallet.

**Validator Parameters:**

```aiken
validator transfer(
  owner: ByteArray,      // Token policy owner
  assetName: ByteArray,  // Asset name
  flagwl: Bool,         // Whitelist active?
  flagbl: Bool,         // Blacklist active?
  flagstatus: Bool      // Custom status active?
)
```

**Redeemer:**

```aiken
Transfer {
  proofsWL: Option<Pairs<ByteArray, Proof>>,    // Merkle proofs whitelist
  proofsBL: Option<Pairs<ByteArray, Proof>>,    // Merkle proofs blacklist
  statusList: Option<List<Data>>,               // Custom status
  token_index: Int                              // Index reference input
}
```

**Entry Points:**

1. **spend()** – Validates UTxO spending
   - Checks presence of withdrawal in the same transaction
   - Delegates main validation to the withdrawal step
2. **withdraw()** – Transaction‑level validation (Withdraw 0)
   - Performs the following validations:
   - **a) token_with_credentials_in_contract()** – Ensures tokens stay in the contract, balances inputs/outputs with minting/burning, validates stake credentials for each input, and checks owner signatures.
   - **b) wl_checks()** (if `flagwl = True`) – For each contract input, includes reference input from whitelist linked list and verifies membership (`node.key == user_hash`).
   - **c) bl_checks()** (if `flagbl = True`) – For each input, includes reference input from blacklist linked list and verifies **non‑membership** (`node.key < user_hash < node.next`).
   - **d) status_check()** – Validates custom status logic if applicable.
   - **e) Linked List Node Verification** – Reference inputs must contain valid nodes from whitelist/blacklist linked list; covering node pattern proves inclusion/exclusion.
3. **mint()** – Allows token minting/burning
   - Only the token owner may mint/burn
   - Validated via `is_owner_signing()`

### 3.3 Checks Validator (`checks.ak`)

**Responsibility:** Utility validator for testing and external oracle validation.

- Validates Ed25519 signatures for oracles
- Contains test Merkle root for blacklist/whitelist
- Example KYC data for testing

---

## 4. DEX Integration Validators

### 4.1 Pool Validator (`pool_validator.ak`)

**Responsibility:** Manages liquidity pools with CIP‑113 token support.

**Validator 1: validate_pool()** – Core pool validation (details omitted for brevity).

**Redeemer Actions:**

1. **Batching** – Authorizes batch execution of orders; verifies presence of `pool_batching_stake_credential` in withdrawals; allows pool reserve updates.
2. **UpdatePoolParameters** – Various sub‑actions:
   - **UpdatePoolFee** – Modifies pool trading fee; requires `pool_fee_updater` authorization; fee numerator must be between 5‑2000 (0.05%‑20%).
   - **UpdateDynamicFee** – Enables/disables dynamic fee; requires `pool_dynamic_fee_updater`.
   - **UpdatePoolStakeCredential** – Changes pool stake credential; requires `pool_stake_key_updater`.
   - **WithdrawFeeSharing** – Withdraws accumulated pool fees; requires `fee_sharing_taker`; preserves Pool NFT and correct datum; fee withdrawal must match reserve differences.

**Validator 2: validate_pool_batching()** – Authorizes batch processing of orders.

- Only authorized batchers (listed in Global Setting) may batch.
- Supports single‑pool and multi‑routing (max 3 pools).
- Checks order expiry times.
- Validates receiver address.
- Batcher fee must satisfy `0 < fee <= max_batcher_fee`.
- Unique, non‑empty input indexes.
- **Reserve Tracking:** Confirms actual asset quantities match datum reserves.
- **Liquidity Supply:** Verifies LP token changes correspond to total liquidity changes.
- **Dynamic Fee:** Calculates trading fee by combining base fee with optional volatility fee (if dynamic fee enabled).

### 4.2 Order Validator (`order_validator.ak`)

**Responsibility:** Validates creation, cancellation, and execution of swap orders.

**Validator 1: validate_order()** – Core order validation.

**Redeemer Actions:**

1. **ApplyOrder** – Executes order during batching.
   - Requires `pool_batching_credential` in withdrawals.
   - Spending authorized only during pool batch.
   - Supports multiple order types: SwapExactIn, SwapExactOut, StopLoss, OCO, Deposit, Withdraw, ZapOut, PartialSwap, WithdrawImbalance, SwapMultiRouting.
   - Validations: positive batcher fee ≤ max, correct LP asset, expiry time if set.
2. **CancelOrderByOwner** – Owner cancels own order.
   - Verifies authorization via `canceller` field in OrderDatum.
   - Supports four authorization methods: direct signature, input spending, withdrawal, minting.
3. **CancelExpiredOrderByAnyone** – Anyone can cancel expired orders.
   - Requires `expired_order_cancel_credential` in withdrawals.
   - Validation: transaction must be created after expiry time.
   - ADA assets may be used as tip for canceller (up to max); non‑ADA assets fully returned to owner.

**Validator 2: validate_expired_order_cancel()** – Batch cancellation of expired orders.

- Filters all inputs from script credentials (orders).
- For each order, checks `expiry_time < start_validity_range`.
- Allows efficient multiple‑order cancellation without requiring owner signature.

### 4.3 Factory Validator (`factory_validator.ak`)

**Responsibility:** Creates new liquidity pools.

**Pool Creation Flow:**

1. **Factory Input** – Must contain exactly one Factory NFT; factory UTxO is spent and recreated.
2. **Asset Sorting** – Assets A and B must be ordered to prevent duplicate pools.
3. **Linked List Update** – Creates two new Factory UTxOs to track the pool:
   - `(old_head, new_lp_asset_name)`
   - `(new_lp_asset_name, old_tail)`
4. **Pool Output Validation** – Exactly one Pool NFT; initial reserves `amount_a > 0`, `amount_b > 0`; total liquidity = `sqrt(amount_a * amount_b)`; default liquidity burned; fee numerator 5‑2000; dynamic fee `FALSE`; no fee sharing.
5. **LP Token Minting** – LP token name computed deterministically: `SHA3(SHA3(tokenA) + SHA3(tokenB))`; minted via Authentication Policy; initial amount = `sqrt(amount_a * amount_b)`.

### 4.4 Authentication Minting Policy (`authen_minting_policy.ak`)

**Responsibility:** Controls minting of authentication NFTs (Factory, Global Setting, Pool NFT, LP tokens).

**Redeemer Actions:**

1. **CreatePool** – Validates Factory input (must contain Factory NFT), correct factory redeemer, asset ordering, authorizes LP token minting for new pool, authorizes Pool NFT minting; fee numerator range 5‑2000; profit sharing numerator 1666‑5000 when enabled.
2. **DexInitialization** (one‑time) – Initializes DEX by minting:
   - 1 Factory NFT
   - 1 Global Setting NFT

**Factory UTxO Initial State:** Empty linked list: `head = #"00"`, `tail = #"ff..ff00"`.

**Global Setting UTxO:** Global DEX configuration:

```
GlobalSetting {
  batchers: [List<Credential>]
  pool_fee_updater: Credential
  fee_sharing_taker: Credential
  pool_stake_key_updater: Credential
  pool_dynamic_fee_updater: Credential
  admin: Credential   // MUST be Multi‑Sig
}
```

**Security Critical:** Admin must be multi‑signature to avoid single point of failure; admin can modify all critical parameters.

---

## 5. Validator Actions and Flows

### 5.1 CIP‑113 Token Transfer Flow

**Action:** Transfer CIP‑113 token from one user to another.

**Smart Contracts Involved:**

- Transfer Logic Script (withdraw 0)
- programmableLogicBase (spend)
- programmableLogicGlobal (withdraw 0, delegation)
- Global State Validator (reference input, if present)
- Registry (reference input for proof)

**Flow:**

1. **Setup Transaction:**
   - **Input:** UTxO with CIP‑113 token from sender’s smart wallet (`programmableLogicBase` payment credential).
   - **Output:** New UTxO to recipient’s smart wallet (same payment credential, different stake credential).
   - **Withdrawal 1:** `programmableLogicGlobal` stake address, amount = 0 (delegation pattern).
   - **Withdrawal 2:** Token‑specific `transferLogicScript`, amount = 0 (custom validation).
   - **Reference Input 1:** RegistryNode (registration proof).
   - **Reference Input 2+:** Nodes from whitelist/blacklist linked list (if active).
2. **Validate programmableLogicBase (Spend):**
   - Checks that `programmableLogicGlobal` is invoked (withdraw 0 present).
   - Delegates all validation to the stake validator.
3. **Validate programmableLogicGlobal (Delegation):**
   - Verifies user authorization (signature or script execution for stake credential).
   - Checks RegistryNode proof (TokenExists).
   - Ensures `transferLogicScript` of the token is executed (present in withdrawals).
   - Confirms token outputs remain at `programmableLogicBase` addresses.
4. **Validate transferLogicScript (Custom Logic):**
   - **token_with_credentials_in_contract():** Checks token balance (input = output ± minting), validates stake credentials for each input, verifies owner signatures.
   - **wl_checks():** If `flagwl` active, verifies covering node from whitelist linked list (node with `key == user_hash`).
   - **bl_checks():** If `flagbl` active, verifies covering node from blacklist linked list (gap: `node.key < user_hash < node.next`).
   - Additional custom token logic as defined.
5. **Completion:**
   - Token transferred to recipient’s smart wallet.
   - All programmed rules (whitelist, blacklist, custom logic) satisfied.
   - Token remains locked in `programmableLogicBase`.

### 5.2 Swap Order Creation

**Action:** User creates order to swap ADA ↔ CIP‑113 token.

**Smart Contracts Involved:**

- Order Validator
- Transfer Validator (if selling CIP‑113 token)

**Buy Order (ADA → CIP‑113):**

1. **Create Order Output:**
   - Destination: Order validator address.
   - Assets: ADA to swap + fees (batcher + tx).
   - Datum: OrderDatum containing:
     - Sender PKH
     - Receiver address (CIP‑113 address)
     - Pool identification (auth policy + LP asset)
     - Order step (amount in, min amount out, direction)
     - Max batcher fee
     - Optional expiry time
2. **Order Pending:** UTxO created at order validator, awaiting batch processing.

**Sell Order (CIP‑113 → ADA):**

1. **Spend CIP‑113 Token:**
   - Input: UTxO with CIP‑113 token.
   - Include Transfer validator script.
   - Withdrawal: CIP‑113 (withdraw 0).
   - Reference Input: Account Manager.
2. **Create Order Output:**
   - Destination: Order validator address.
   - Assets: CIP‑113 token to swap + fees.
   - Datum: OrderDatum (same structure as above).
3. **Order Pending:** UTxO at order validator.

### 5.3 Order Batching

**Action:** Authorized batcher processes a batch of orders.

**Smart Contracts Involved:**

- Pool Validator (spend + batching withdrawal)
- Order Validator (spend)
- Transfer Validator (withdraw per CIP‑113 token)

**Flow:**

1. **Fetch Pending Orders:** Query UTxOs at order validator address; parse each OrderDatum.
2. **Construct Transaction:**
   - **Inputs:** Pool UTxO (spending), Order UTxO(s) (spending).
   - **Withdrawals:**
     - Pool Batching Validator (authorizes batcher)
     - Pool Validator (authorizes pool spending)
     - Order Validator (authorizes apply order)
     - Transfer Validator (if CIP‑113 token, withdraw 0)
   - **Reference Inputs:**
     - Global Setting UTxO (checks batcher authorized)
     - RegistryNode UTxO (proof of token registration)
     - Whitelist/Blacklist Linked List Nodes (if token restrictions active)
   - **Outputs:**
     - Recipient outputs (swapped assets to recipients)
     - Updated Pool UTxO (new reserves)
3. **Pool Batching Validation:**
   - Verify batcher is listed in authorized batchers (Global Setting).
   - Validate batcher fee.
   - Support single‑pool and multi‑routing (max 3 pools).
   - Check order expiry times.
   - Validate receiver address.
   - Ensure correct fee calculations.
4. **Swap Calculations (Constant Product):**
   - **SwapExactIn:**
     ```
     in_with_fee = amount_in * (10000 - fee) / 10000
     amount_out = (in_with_fee * reserve_out) / (reserve_in + in_with_fee)
     ```
   - **SwapExactOut:**
     ```
     amount_in = (reserve_in * amount_out * fee_denominator) /
                 ((reserve_out - amount_out) * fee_adjusted_denominator) + 1
     ```
   - **Initial Liquidity Calculation:**
     ```
     initial_liquidity = sqrt(amount_a * amount_b)
     ```
5. **Update Pool State:**
   - New reserves calculated.
   - Pool datum updated.
   - Pool NFT preserved.
6. **Completion:** Tokens delivered to recipients; orders removed; fees distributed.

### 5.4 Order Cancellation

**Action:** Cancel pending order.

**Cancel by Owner:**

- Owner signs transaction.
- Spend order UTxO with redeemer `CancelOrderByOwner`.
- Verify authorization via `canceller` field in OrderDatum.
- Supports four authorization methods: direct signature, input spending, withdrawal, minting.

**Cancel Expired by Anyone:**

- Anyone can create transaction.
- Filter expired orders (`expiry_time < validity_range_start`).
- Spend order UTxO with redeemer `CancelExpiredOrderByAnyone`.
- Requires `expired_order_cancel_credential` in withdrawals.
- ADA may be used as tip for canceller (up to max); non‑ADA assets fully returned to owner.

**Batch Expired Cancellation:**

- Filters all inputs from script credentials (orders).
- Checks each order’s expiry.
- Allows efficient multiple order cancellations without owner signature.

### 5.5 Pool Creation

**Action:** Create a new liquidity pool.

**Smart Contracts Involved:**

- Factory Validator (spend)
- Authentication Policy (mint)
- Pool Validator (receive)

**Flow:**

1. **Spend Factory:**
   - Input: Factory UTxO containing Factory NFT.
   - Verify assets are ordered.
2. **Mint NFTs and LP Token:**
   - Authentication Policy mints:
     - 1 Pool NFT
     - LP tokens (name computed deterministically)
3. **Outputs:**
   - **Updated Factory (Linked List):** Two Factory UTxOs to track new pool:
     - `(old_head, new_lp_asset)`
     - `(new_lp_asset, old_tail)`
   - **Pool UTxO:**
     - Address: Pool validator address.
     - Assets: 1 Pool NFT + reserve_a + reserve_b.
     - Datum: PoolDatum with:
       - Initial reserves
       - Total liquidity = `sqrt(amount_a * amount_b)`
       - Fee numerator range 5‑2000
       - Dynamic fee `FALSE`
       - No fee sharing
4. **Validations:**
   - Asset sorting correct.
   - Reserves > 0.
   - Fee numerator within range.
   - Default liquidity burned.
   - Factory NFT preserved.
5. **Completion:** New pool ready for swaps and liquidity provision.

### 5.6 Insert into Whitelist/Blacklist Linked List

**Action:** Add address to whitelist/blacklist (admin operation).

**Smart Contracts Involved:**

- Linked List Validator (spend)
- Potentially `thirdPartyTransferLogicScript` for admin authorization.

**Flow:**

1. **Input:** Previous node in whitelist linked list where `prev.key < new_hash < prev.next`.
2. **Redeemer:**
   ```aiken
   Insert {
     new_key: ByteArray,        // Address hash to add (28 bytes)
   }
   ```
3. **Validation:**
   - Verify admin (owner) signature.
   - Maintain lexicographic ordering: `prev.key < new_key < prev.next`.
   - Spend previous node and recreate with updated `next`.
   - Create new node with unique NFT identifier.
4. **Outputs:**
   - Updated previous node pointing to new node.
   - New node inserted at correct position.
5. **InsertBL:** Same as InsertWL but operates on blacklist linked list.

---

## 6. Security

### 6.1 Smart Contract Security Measures

- **Multi‑Signature Admin:** Admin of Global Setting must be multi‑sig to avoid single point of failure.
- **Critical On‑Chain Validations:**
  1. Asset Sorting (Factory) – prevents duplicate pools for same asset pair.
  2. Fee Bounds (Pool) – min 5 (0.05%), max 2000 (20%) to prevent predator configurations.
  3. Expiry Time (Order) – only expired orders cancellable by anyone.
  4. Authorized Batchers (Pool Batching) – only batchers in whitelist Global Setting.
  5. Token Locking (Transfer) – mathematical check: input tokens = output tokens (± minting); tokens cannot be extracted from contract without validation.
  6. Merkle Proof Validation (Transfer) – whitelist inclusion, blacklist exclusion.

### 6.2 Validation Details

1. **Asset Sorting (Factory)** – prevents duplicate pools for same asset pair.
2. **Fee Bounds (Pool)** – min 5 (0.05%), max 2000 (20%).
3. **Expiry Time (Order)** – only expired orders cancellable by anyone; active orders require owner signature.
4. **Authorized Batchers (Pool Batching)** – only batchers listed in Global Setting.
5. **Token Locking (Transfer)** – ensures input tokens equal output tokens (± minting).
6. **Merkle Proof Validation (Transfer)** – whitelist inclusion, blacklist exclusion.

---

## 7. References

### Repository

- **FluidTokens CIP‑113**
  - GitHub: https://github.com/FluidTokens/ft-cip-113
  - Contains: Aiken validators, Blueprint JSON, Test suites

- **Minswap DEX v2**
  - GitHub: https://github.com/minswap/minswap-dex-v2
  - Branch: v2.1
  - Key modules used:
    - `math.ak`: AMM calculations (swap, liquidity, fee)
    - `types.ak`: Datum and redeemer definitions
    - `pool_validation.ak`: Pool and batching validations
    - `order_validation.ak`: Order validations and execution
    - `utils.ak`: Utility functions

### Technical Documentation

- **CIP‑113 Specification**
  - URL: https://github.com/cardano-foundation/cip113-programmable-tokens
  - Official specification: motivation, architecture, examples

- **Aiken Language**
  - URL: https://aiken-lang.org/
  - Language guide, standard library, best practices

- **Merkle Patricia Forestry**
  - URL: https://github.com/aiken-lang/merkle-patricia-forestry
  - Aiken library for Merkle Patricia Trees

- **Cardano Foundation – CIPs**
  - URL: https://github.com/cardano-foundation/CIPs
  - All Cardano Improvement Proposals

_Documentation last updated: January 2026_
