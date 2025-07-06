# Blockchain Based E-Voting System 

A secure, transparent, and decentralized e-voting system built on zkSync Era, leveraging blockchain technology to ensure tamper-proof elections and verifiable results.

## 🌟 Features

- **Secure Voter Registration**: Biometric-based voter registration with robust identity verification
- **Role-Based Access Control**: Granular permission management for system administrators and voters
- **Proposal Management**: Create, manage, and track voting proposals
- **Real-time Vote Tracking**: Monitor voting progress and results in real-time
- **Transparent Vote Counting**: Verifiable and immutable vote counting mechanism
- **Zero-Knowledge Proofs**: Enhanced privacy through zkSync Era's Layer 2 scaling solution

## 🏗 Architecture

The system consists of several smart contracts working together:

- **AccessControlManager (AC)**: Manages roles and permissions
- **VoterRegistry**: Handles voter registration and verification
- **ProposalState**: Maintains proposal states and vote counts
- **ProposalValidator**: Validates voting rules and constraints
- **ProposalOrchestrator**: Coordinates proposal lifecycle
- **VotingFacade**: Main entry point for interacting with the system

## 📦 Deployed Contracts (zkSync Sepolia)
```solidity
AccessControlManager  : 0x3EDeB25800D4bCC02F1134605993a4E580b381D3
VoterRegistry         : 0xdE31ef595B91511c624ba2B6cc284Db1D6F3d09f
ProposalState         : 0xC8076182526163289232C65b89558Fe16Ae420b2
ProposalValidator     : 0x9C642213E321EB9BC8BAe9F4007e44164e483E1B
ProposalOrchestrator  : 0x1B81F6c5E2Fda6914b3e213B7fbb2B3d2Ace3CdA
VotingFacade (main)   : 0x080b2492B403758aDe9a249FDf245302C860BD63
```

## 🛠 Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [zkSync Era](https://era.zksync.io/docs/dev/building-on-zksync/hello-world.html)
- Node.js & npm/yarn

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd smart-contracts
```

2. Install dependencies
```bash
forge install
```

3. Build contracts
```bash
forge build
```

4. Run tests
```bash
forge test
```

## 🧪 Testing

The test suite is organized into:

- **Unit Tests**: Individual contract functionality testing
- **Integration Tests**: Cross-contract interaction testing
- **Comprehensive Tests**: End-to-end system testing

Run specific test categories:
```bash
# Run unit tests
forge test --match-path test/unit/*

# Run integration tests
forge test --match-path test/integration/*
```




