# Blockchain NFTs and Smart Contracts in Mojo Grizzly

Extends blockchain with NFT minting and smart contract deployment.

## Commands
BLOCKCHAIN MINT NFT 'metadata'  # Mints NFT

BLOCKCHAIN DEPLOY CONTRACT 'code'  # Deploys contract

## Implementation
- NFT struct with id, metadata, owner
- SmartContract struct with id, code
- Stored in global lists
- Builds on existing blockchain ext