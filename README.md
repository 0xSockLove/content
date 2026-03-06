# Content

A custom 42-line ERC1155 smart contract for minting adult content as SFTs. Owned by a 2-of-2 Gnosis Safe — neither partner can act alone.

## Architecture

Sockpusher and Sockthief share a [Gnosis Safe](https://safe.global) wallet. It's a 2-of-2 multisig — every action requires both signatures.
```
┌─────────────────────────────────┐
│       Gnosis Safe (2-of-2)      │
│     Sockpusher + Sockthief      │
│                                 │
│  • Deploys contracts            │
│  • Mints/sells tokens           │
│  • Receives payments            │
│  • Signs every decision         │
└────────────────┬────────────────┘
                 │ owns
                 ▼
┌─────────────────────────────────┐
│          Content.sol            │
│                                 │
│  mint() ──► both must sign      │
│  tokens ──► held by Safe        │
│  sales ───► ETH to Safe         │
└─────────────────────────────────┘
```

One cannot deploy without the other. One cannot mint without the other. One cannot sell without the other. One cannot withdraw without the other.

## Contract

**Content.sol** is an ERC1155 token contract. All content becomes tokens with sequential IDs and per-token metadata URI.
```solidity
function mint(string calldata _uri, uint256 _amount) external onlyOwner returns (uint256 id)
function uri(uint256 _id) public view returns (string memory)
```

**Features:**
- Owner-only minting (Safe is owner)
- Sequential token IDs (1, 2, 3...)
- Per-token metadata URIs
- `Minted` event for indexing
- Custom errors (`EmptyURI`, `ZeroAmount`)

**What it doesn't have (by design):**
- No burn — content is permanent
- No pause — Safe can just stop signing
- No URI updates — immutable for collectors
- No royalties (EIP-2981) — revenue from direct sales only

## Setup
```bash
git clone https://github.com/0xSockLove/content.git
cd content
forge install
```

## Build
```bash
forge build
```

## Test
```bash
forge test
```

**10 tests with 100% coverage of custom logic:**

| Test | What it checks |
|------|----------------|
| `test_Mint_Success` | Minting works, returns ID, stores URI |
| `test_Mint_SequentialIds` | IDs increment 1, 2, 3... |
| `test_Mint_RevertsIfNotOwner` | Only owner can mint |
| `test_Mint_RevertsIfEmptyURI` | Empty URI rejected |
| `test_Mint_RevertsIfZeroAmount` | Zero amount rejected |
| `test_Mint_EmitsMintedEvent` | Event emission verified |
| `test_Uri_ReturnsEmptyForNonexistentToken` | Handles unminted tokens |
| `test_Transfer_Success` | ERC1155 transfers work |
| `testFuzz_Mint_AnyAmount` | Fuzz: 256 runs, any valid amount |
| `testFuzz_Mint_AnyURI` | Fuzz: 256 runs, any valid URI |

**Coverage:** 100% of custom logic plus integration tests verifying ERC1155 transfers and Ownable access control work correctly.

## Deploy

### Testnet (direct)
```bash
forge script script/DeployContent.s.sol --rpc-url $SEPOLIA_RPC --broadcast --private-key $PRIVATE_KEY
```

### Mainnet (via Gnosis Safe)

The contract is deployed directly by the Safe using CreateCall. This ensures:
- Safe becomes owner atomically (no transfer needed)
- Both signers must approve deployment
- No intermediate deployer wallet needed

#### Step-by-Step Deployment Guide

**1. Generate Deployment Bytecode**

```bash
forge inspect Content bytecode
```

This outputs the contract creation bytecode. Copy it to your clipboard.

**2. Open Safe Transaction Builder**

Navigate to [app.safe.global](https://app.safe.global):
- Select your Safe (2-of-2 multisig)
- Click "New Transaction"
- Select "Transaction Builder"

**3. Configure CreateCall Transaction**

Enter the following values:

| Field | Value |
|-------|-------|
| **Contract Address** | `0x9b35Af71d77eaf8d7e40252370304687390A1A52` |
| **Contract Method Selector** | `performCreate` |
| **value (wei)** | `0` |
| **deploymentData (bytes)** | *Paste bytecode from step 1* |

**Why CreateCall?**
- The CreateCall library (deployed on all chains) creates contracts with `msg.sender` = Safe
- This makes Safe the owner immediately, with no ownership transfer needed
- Both signers approve deployment before contract exists

**4. Simulate Transaction**

Before signing:
- Click "Simulate" in the Safe UI
- Verify the transaction will succeed
- Check estimated gas costs
- Both signers should independently verify the bytecode hash

**5. First Signer Approves**

- Review all transaction details
- Confirm the bytecode matches `forge inspect Content bytecode`
- Sign with hardware wallet
- Transaction enters pending state

**6. Second Signer Verifies & Approves**

- **DO NOT BLINDLY SIGN**
- Independently verify bytecode matches expected contract
- Simulate transaction on your own device
- Confirm gas estimates are reasonable
- Sign with hardware wallet

**7. Execute Transaction**

- One signer executes (pays gas)
- Transaction is broadcast to network
- Wait for confirmation (1-2 minutes on mainnet)
- Contract address appears in transaction receipt

**8. Post-Deployment Verification**

```bash
# Get contract address from transaction receipt
CONTRACT_ADDRESS=<address_from_receipt>

# Verify owner is Safe
cast call $CONTRACT_ADDRESS "owner()" --rpc-url $MAINNET_RPC
# Should return: <YOUR_SAFE_ADDRESS>

# Verify no tokens minted yet
cast call $CONTRACT_ADDRESS "balanceOf(address,uint256)" $SAFE_ADDRESS 1 --rpc-url $MAINNET_RPC
# Should return: 0x0000000000000000000000000000000000000000000000000000000000000000

# Verify on Etherscan
forge verify-contract $CONTRACT_ADDRESS Content \
  --chain mainnet \
  --watch \
  --constructor-args $(cast abi-encode "constructor()")
```

**9. Document Deployment**

Save the following for your records:
- Contract address
- Deployment transaction hash
- Block number
- Both signer addresses
- Etherscan verification URL

**Emergency Rollback:**

If deployment fails or the contract address is wrong:
- The Safe can deploy a new contract (repeat steps 1-8)
- Each Safe nonce can only be used once, preventing replay attacks
- No risk of double-deployment if transaction reverts

## Mint

Once deployed, minting happens through the Safe Transaction Builder.

### Minting Workflow

**1. Prepare Metadata**
```bash
# Upload content to IPFS/Arweave
ipfs add video.mp4  # Returns: QmContentHash

# Create metadata JSON (example format - SockLove uses its own metadata standard)
{
  "name": "Content Title",
  "description": "Description",
  "image": "ipfs://QmThumbnailHash",
  "animation_url": "ipfs://QmContentHash"
}

# Upload metadata
ipfs add metadata.json  # Returns: QmMetadataHash
```

**2. Mint via Safe**

Navigate to [app.safe.global](https://app.safe.global):
- Select your Safe
- New Transaction → Transaction Builder
- **To Address:** `<CONTRACT_ADDRESS>`
- **Function:** `mint(string _uri, uint256 _amount)`
- **\_uri:** `ipfs://QmMetadataHash`
- **\_amount:** `1` (for 1/1) or `100` (for editions)

**3. Approve & Execute**
- First signer reviews and signs
- Second signer verifies URI and signs
- One signer executes (pays gas)

**4. Verify**
```bash
# Check token minted correctly
cast call $CONTRACT_ADDRESS "uri(uint256)" 1 --rpc-url $MAINNET_RPC

# Check Safe received tokens
cast call $CONTRACT_ADDRESS "balanceOf(address,uint256)" $SAFE_ADDRESS 1 --rpc-url $MAINNET_RPC
```

Tokens mint to the Safe. Both signers must approve every mint. Transfer or list on marketplaces afterward.

## Royalties

**SockLove does not use royalties.**

The contract intentionally does NOT implement EIP-2981 (the NFT royalty standard). This is a deliberate design decision because:

- All revenue comes from direct sales, not secondary market fees
- EIP-2981 is not enforceable on-chain (marketplaces can ignore it)
- Most major marketplaces have made royalties optional
- Peer-to-peer transfers bypass royalties regardless of on-chain standards
- Excluding royalty code keeps the contract minimal and gas-efficient

This aligns with SockLove's business model: scarcity and primary sales, not ongoing secondary fees.

## Project Structure
```
content/
├── .github/
│   └── workflows/
│       └── test.yml         # CI/CD test automation
├── .gitignore
├── .gitmodules
├── foundry.lock
├── foundry.toml
├── lib/
│   ├── forge-std/           # Foundry standard library
│   └── openzeppelin-contracts/  # OpenZeppelin v5.6.1
├── README.md                # Project overview, setup, deployment, minting
├── remappings.txt
├── script/
│   └── DeployContent.s.sol  # Deployment script
├── src/
│   └── Content.sol          # 42 lines
└── test/
    └── ContentTest.t.sol    # 10 tests (100% coverage)
```

## Dependencies

- [OpenZeppelin Contracts v5.6.1](https://github.com/OpenZeppelin/openzeppelin-contracts) — Pinned in `foundry.toml`
- [Foundry](https://book.getfoundry.sh) — Smart contract development framework

## License

MIT