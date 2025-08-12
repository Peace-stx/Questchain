# Questchain

A gamified bounties and task system for communities built on Stacks blockchain, enabling smart contract-powered quest boards to incentivize contributions.

## Overview

Questchain allows communities to create bounty-based tasks (quests) with automated reward distribution and reputation tracking through NFTs. Contributors can submit work, get verified, and earn both STX rewards and reputation NFTs.

## Features

- **Quest Creation**: Community leaders can create bounty tasks with STX rewards
- **Submission System**: Contributors submit work with automatic or manual verification
- **Reward Distribution**: Automated STX distribution upon quest completion
- **Reputation NFTs**: Milestone-based NFT rewards for active contributors
- **Community Management**: Quest approval, rejection, and cancellation capabilities

## Smart Contract Functions

### Core Quest Functions
- `create-quest`: Create new bounty tasks with STX rewards
- `submit-to-quest`: Submit work for quest completion
- `approve-submission`/`reject-submission`: Verify submitted work
- `cancel-quest`: Cancel active quests and refund rewards

### Reputation System
- `mint-reputation-nft`: Mint achievement NFTs at completion milestones
- `update-user-reputation`: Track user contribution metrics

### Read Functions
- `get-quest`: Retrieve quest details
- `get-submission`: Get submission information
- `get-user-reputation`: View user reputation data

## Installation

1. Clone the repository
2. Install Clarinet: `curl -L https://github.com/hirosystems/clarinet/releases/download/v1.8.0/clarinet-linux-x64.tar.gz | tar xz`
3. Run tests: `clarinet test`
4. Deploy: `clarinet deploy --testnet`

## Usage Example

```clarity
;; Create a quest
(contract-call? .questchain create-quest 
    "Build DeFi Interface"
    "Create UI for token swapping functionality"
    u1000000  ;; 1 STX reward
    u1000     ;; Deadline in blocks
    u3        ;; Max 3 submissions
    true      ;; Verification required
)

;; Submit work
(contract-call? .questchain submit-to-quest
    u1
    "Completed DeFi interface with swap functionality - GitHub: repo-link"
)
```

## Future Development

This implementation provides the foundation for a comprehensive quest-based community incentive system with built-in reputation tracking and automated reward distribution.

### Planned Upgrade Features

1. **Multi-Token Rewards**: Support for SIP-010 fungible tokens as quest rewards beyond STX
2. **Quest Categories & Tags**: Categorization system with filtering capabilities for different quest types
3. **Team Quests**: Multi-contributor quests with reward splitting mechanisms
4. **Time-Locked Rewards**: Vesting schedules for large quest rewards over time
5. **Quest Templates**: Pre-built quest templates for common community tasks
6. **Skill-Based Matching**: Match contributors to quests based on their reputation specializations
7. **Quest Dependencies**: Chain quests together with prerequisite requirements
8. **Community Voting**: Decentralized verification through community voting mechanisms
9. **Achievement Badges**: Specialized NFT badges for different types of contributions
10. **Cross-Community Quests**: Multi-community collaborations with shared quest pools

