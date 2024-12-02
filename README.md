# ft-cip-113

This repository contains the code for a **programmable token DEX integration** using CIP-113 tokens. It implements a standard interface to manage the lifecycle and functionality of these programmable tokens while ensuring compatibility with the Cardano blockchain architecture.

## Overview

### What is CIP-113?

CIP-113 introduces a specification for **programmable tokens** on the Cardano blockchain. These tokens behave like native assets but remain forever locked inside smart contracts. This design ensures programmability while avoiding risks such as unintentionally locking non-programmable native tokens. CIP-113 tokens enable advanced functionality, such as:

- **Optional Blacklisting & Whitelisting:** Add or restrict access to specific users or contracts.
- **Pause All Transfers:** A global switch to halt token activity.
- **Custom User States:** Define specific rules or attributes for each user.
- **Programmable Spending Conditions:** Set custom logic for using tokens.
- **Seamless DeFi Integration:** Allow CIP-113 tokens to interact with other dApps and native assets.

By enforcing these features, CIP-113 tokens provide the flexibility needed for advanced DeFi protocols while maintaining compatibility with the Cardano UTXO model.

---

### How Does It Work?

CIP-113 defines several validators and state management techniques to enforce programmability while maintaining efficiency:

- **Merkle Trees** manage global states like blacklists/whitelists off-chain, keeping on-chain data minimal.
- **Validators** manage specific token lifecycle events and interactions, such as minting, transferring, and spending.
- **Withdraw 0 Trick:** Ensures secure validation of CIP-113 token transfers without requiring predefined datums.

The repository is divided into two main parts:

---

## 1. DEX Validators (`dexValidators` folder)

This module manages the interaction of CIP-113 tokens within the decentralized exchange (DEX). Key features include:

- **Order Management:**
  - **Create Orders:** Users define token swap requests.
  - **Submit Orders:** Execute token swaps securely.
  - **Cancel Orders:** Remove pending orders.
- **Swap Logic:** Executes token swaps while ensuring compliance with CIP-113 token rules and programmability.

These validators enforce the logic for seamless DEX integration of CIP-113 tokens alongside native assets.

---

## 2. Token Validators (`validators` folder)

This module contains the logic to enforce the lifecycle and programmability of CIP-113 tokens. Key features include:

- **Lifecycle Management:**
  - **Minting:** Issue tokens while ensuring compliance with CIP-113 specifications.
  - **Burning:** Remove tokens from circulation as required.
  - **State Updates:** Adjust token states (e.g., pause, blacklist) dynamically.
- **Validator Functions:**
  - **Hub Spend:** Centralized state management for CIP-113 tokens.
  - **Account Management:** Manage global states like transfer pauses and blacklists/whitelists.
  - **Transfer Logic:** Ensure CIP-113 tokens remain within their designated smart contract environments.

These validators guarantee that CIP-113 tokens adhere to their programmable standards throughout their lifecycle.

---

## CIP-113 Features in Practice

1. **Programmable Logic:** 
   - Use CIP-113 tokens like native assets, but with added programmability.
   - Define custom spending conditions to meet protocol-specific requirements.

2. **Secure State Management:** 
   - Implement blacklisting/whitelisting and pausing transfers using merkle trees to track global states.

3. **Interoperability:** 
   - Support seamless integration with other DeFi protocols and native tokens.

---

## How to Use

1. **Clone the Repository:**

    ```bash
    git clone https://github.com/fluidtokens/ft-cip-113.git
    cd ft-cip-113
    ```

2. **Explore the Modules:**
   - Navigate to the `dexValidators` folder for DEX-specific functionality.
   - Navigate to the `validators` folder for token lifecycle and programmability logic.

3. **Deploy Validators:** 
   - Use Plutus, Cardano CLI, or your preferred smart contract deployment toolset.

---

## Contribution

We welcome contributions to improve the repository. Feel free to:

- Submit issues or feature requests.
- Open pull requests with proposed changes.
- For significant modifications, please open an issue to discuss your ideas.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

By incorporating the principles and specifications of CIP-113, this repository enables seamless integration of programmable tokens into decentralized exchanges, paving the way for more advanced and flexible DeFi protocols on Cardano.
