# ft-cip-113

This repository contains the code for creating a programmable token DEX integration with CIP-113 tokens. It is split into two main parts, each covering a specific aspect of the integration:

1. **DEX Validators** (`dexValidators` folder)
2. **Token Validators** (`validators` folder)

## Overview

### What is CIP-113?
CIP-113 refers to a proposal for managing the lifecycle and functionality of native tokens on the Cardano blockchain. It allows enhanced programmability and governance capabilities for tokens. This repository utilizes CIP-113 to integrate tokens into a decentralized exchange (DEX), making them programmable and functional within smart contracts.

### How Does It Work?
The repository is structured into two main components, described below:

---

## 1. DEX Validators (`dexValidators` folder)

This section contains the logic related to the decentralized exchange (DEX) integration. Key functionalities include:

- **Create Orders**: Allows users to create orders for token swaps.
- **Submit Orders**: Enables users to submit or fill orders, executing a swap between tokens.
- **Cancel Orders**: Provides the ability for users to cancel existing open orders, withdrawing their tokens.
- **Swap Logic**: Code for executing token swaps between CIP-113 tokens and other native tokens.

These validators define the rules and logic that govern the order creation, cancellation, and swapping process within the DEX.

---

## 2. Token Validators (`validators` folder)

This section contains the lifecycle management code for CIP-113 tokens. It includes:

- **CIP-113 Token Logic**: Defines how CIP-113 tokens are issued, transferred, and managed within the DEX.
- **Lifecycle Management**: Code that handles the lifecycle events of CIP-113 tokens, such as minting, burning, and updating token states.

These validators are responsible for enforcing the rules around CIP-113 tokens as they are utilized within the DEX environment.

---

## How to Use

1. Clone the repository:

    ```bash
    git clone https://github.com/fluidtokens/ft-cip-113.git
    cd ft-cip-113
    ```

2. Navigate to the desired folder (`dexValidators` or `validators`) to explore the specific logic you're interested in.

3. Deploy the validators using your preferred Cardano smart contract toolset (e.g., Plutus or Cardano CLI).

---

## Contribution

Feel free to contribute by submitting issues or pull requests. For major changes, please open an issue first to discuss what you would like to change.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
