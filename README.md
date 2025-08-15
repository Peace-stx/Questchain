# Questchain

A gamified bounties and task system for communities built on Stacks blockchain, enabling smart contract-powered quest boards to incentivize contributions with multi-token reward support.

## Overview

Questchain allows communities to create bounty-based tasks (quests) with automated reward distribution and reputation tracking through NFTs. Contributors can submit work, get verified, and earn both STX/SIP-010 token rewards and reputation NFTs.

## Features

### Core Functionality
* **Multi-Token Quest Creation**: Create bounty tasks with STX or SIP-010 token rewards
* **Flexible Submission System**: Contributors submit work with automatic or manual verification
* **Advanced Reward Distribution**: Automated STX distribution and manual SIP-010 token distribution upon quest completion
* **Reputation NFTs**: Milestone-based NFT rewards for active contributors (every 5 completed quests)
* **Comprehensive Management**: Quest approval, rejection, and cancellation with proper refund mechanisms

### Multi-Token Support
* **STX Quests**: Fully automated creation, distribution, and cancellation
* **SIP-010 Token Quests**: Support for any SIP-010 compliant token with trait-based implementation
* **Token Management**: Admin functions to add and manage supported token contracts
* **Flexible Architecture**: Separate handling for different token types with proper validation

## Smart Contract Functions

### Quest Management
* **`create-stx-quest`**: Create STX-based bounty tasks (fully automated)
* **`create-token-quest`**: Create SIP-010 token-based quests
* **`create-quest`**: Backward-compatible STX quest creation
* **`submit-to-quest`**: Submit work for quest completion
* **`approve-submission`/`reject-submission`**: Verify submitted work
* **`cancel-quest`**: Cancel STX quests with automatic refunds
* **`cancel-sip010-quest-with-refund`**: Cancel token quests with manual refund handling

### Token & Reward Management
* **`add-supported-token`**: Add new SIP-010 tokens to supported list (admin only)
* **`toggle-token-support`**: Enable/disable token support (admin only)
* **`distribute-sip010-reward-with-trait`**: Manual SIP-010 reward distribution

### Reputation System
* **`admin-mint-reputation-nft`**: Manual NFT minting (admin only)
* **Automatic NFT minting**: At every 5 quest completion milestone
* **Reputation tracking**: Total quests completed, reputation score, and NFT count

### Read Functions
* **`get-quest`**: Retrieve quest details
* **`get-quest-with-reward-info`**: Get quest with complete reward information
* **`get-submission`**: Get submission information
* **`get-user-reputation`**: View user reputation data
* **`get-supported-token`**: Check token support status
* **`is-token-enabled`**: Verify if a token is currently enabled

## Installation

1. Clone the repository
2. Install Clarinet: `curl -L https://github.com/hirosystems/clarinet/releases/download/v1.8.0/clarinet-linux-x64.tar.gz | tar xz`
3. Run tests: `clarinet test`
4. Deploy: `clarinet deploy --testnet`

## Usage Examples

### STX Quest (Fully Automated)
```clarity
;; Create an STX quest
(contract-call? .questchain create-stx-quest 
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

;; Approval automatically distributes STX rewards
```

### SIP-010 Token Quest
```clarity
;; First, admin adds token support
(contract-call? .questchain add-supported-token 
    'SP123...token-contract
    "My Token"
    "MTK"
    u6  ;; 6 decimals
)

;; Create a token quest
(contract-call? .questchain create-token-quest 
    "Design Community Logo"
    "Create brand identity for the community"
    u100000000  ;; 100 tokens (with 6 decimals)
    u2000       ;; Deadline
    u5          ;; Max submissions
    true        ;; Verification required
    .my-token   ;; Token contract trait
)

;; Submit and approve work
(contract-call? .questchain submit-to-quest u1 "Logo designs completed - link")
(contract-call? .questchain approve-submission u1)

;; Manually distribute token rewards
(contract-call? .questchain distribute-sip010-reward-with-trait 
    u1 
    'SP456...recipient 
    .my-token
)
```

## Architecture

### Token Type Handling
- **STX Quests**: Fully automated workflow from creation to reward distribution
- **SIP-010 Quests**: Semi-automated with manual reward distribution for maximum flexibility
- **Validation**: All token contracts are validated using `is-standard` checks
- **Security**: Proper authorization and token contract verification throughout

### Reputation System
- **Automatic NFT Minting**: Every 5 completed quests triggers automatic NFT creation
- **Reputation Scoring**: 10 points per completed quest
- **NFT Metadata**: Includes reputation level, quest count, and minting timestamp

## Future Development

This implementation provides a robust foundation for a comprehensive quest-based community incentive system with multi-token support, built-in reputation tracking, and automated reward distribution.

### Planned Upgrade Features

1. ~~**Multi-Token Rewards**: Fully automated SIP-010 token distribution~~
2. **Quest Categories & Tags**: Categorization system with filtering capabilities
3. **Team Quests**: Multi-contributor quests with reward splitting mechanisms
4. **Time-Locked Rewards**: Vesting schedules for large quest rewards
5. **Quest Templates**: Pre-built templates for common community tasks
6. **Skill-Based Matching**: Match contributors based on reputation specializations
7. **Quest Dependencies**: Chain quests with prerequisite requirements
8. **Community Voting**: Decentralized verification through voting mechanisms
9. **Achievement Badges**: Specialized NFT badges for contribution types
10. **Cross-Community Quests**: Multi-community collaborations with shared pools

## Version

**Current Version**: 2.0 - Multi-Token Reward Support

## License

This project is open-source and available under the MIT License.