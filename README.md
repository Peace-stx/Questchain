# Questchain

A gamified bounties and task system for communities built on Stacks blockchain, enabling smart contract-powered quest boards to incentivize contributions with multi-token reward support and advanced categorization.

## Overview

Questchain allows communities to create bounty-based tasks (quests) with automated reward distribution and reputation tracking through NFTs. Contributors can submit work, get verified, and earn both STX/SIP-010 token rewards and reputation NFTs. The system now includes comprehensive categorization and tagging for better quest organization and discovery.

## Features

### Core Functionality
* **Multi-Token Quest Creation**: Create bounty tasks with STX or SIP-010 token rewards
* **Flexible Submission System**: Contributors submit work with automatic or manual verification
* **Advanced Reward Distribution**: Automated STX distribution and manual SIP-010 token distribution upon quest completion
* **Reputation NFTs**: Milestone-based NFT rewards for active contributors (every 5 completed quests)
* **Comprehensive Management**: Quest approval, rejection, and cancellation with proper refund mechanisms

### Categories & Tags System (New in v2.1)
* **Quest Categories**: Organized quest types with dedicated category management
* **Tag System**: Up to 5 custom tags per quest for detailed classification
* **Difficulty Levels**: Four-tier difficulty system (beginner, intermediate, advanced, expert)
* **Advanced Filtering**: Query quests by category, tags, or difficulty level
* **Category Analytics**: Track quest counts and activity per category

### Multi-Token Support
* **STX Quests**: Fully automated creation, distribution, and cancellation
* **SIP-010 Token Quests**: Support for any SIP-010 compliant token with trait-based implementation
* **Token Management**: Admin functions to add and manage supported token contracts
* **Flexible Architecture**: Separate handling for different token types with proper validation

## Smart Contract Functions

### Category Management
* **`create-category`**: Create new quest categories with name and description
* **`toggle-category`**: Enable/disable categories (admin only)
* **`get-category`**: Retrieve category details by ID
* **`get-category-by-name`**: Find category by name
* **`get-category-count`**: Get total number of categories

### Enhanced Quest Management
* **`create-stx-quest-with-tags`**: Create STX quests with categories, tags, and difficulty
* **`create-token-quest-with-tags`**: Create SIP-010 token quests with full categorization
* **`create-stx-quest`**: Create STX-based bounty tasks (fully automated)
* **`create-token-quest`**: Create SIP-010 token-based quests
* **`create-quest`**: Backward-compatible STX quest creation
* **`submit-to-quest`**: Submit work for quest completion
* **`approve-submission`/`reject-submission`**: Verify submitted work
* **`cancel-quest`**: Cancel STX quests with automatic refunds
* **`cancel-sip010-quest-with-refund`**: Cancel token quests with manual refund handling

### Quest Discovery & Filtering
* **`get-quest-with-tags`**: Retrieve quest with all tag information
* **`get-quest-tags`**: Get tags, category, and difficulty for a quest
* **`is-quest-in-category`**: Check if quest belongs to specific category
* **`is-quest-tagged`**: Check if quest has specific tag

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

### Creating Categories
```clarity
;; Create development category
(contract-call? .questchain create-category 
    "Development"
    "Smart contracts, web development, and technical implementations"
)

;; Create design category
(contract-call? .questchain create-category 
    "Design"
    "UI/UX design, graphics, and visual content creation"
)
```

### STX Quest with Categories & Tags
```clarity
;; Create a categorized STX quest
(contract-call? .questchain create-stx-quest-with-tags
    "Build DeFi Interface"
    "Create responsive UI for token swapping with modern design principles"
    u1000000  ;; 1 STX reward
    u1000     ;; Deadline in blocks
    u3        ;; Max 3 submissions
    true      ;; Verification required
    u1        ;; Development category
    (list "frontend" "defi" "react" "typescript" "")  ;; Tags (up to 5)
    "intermediate"  ;; Difficulty level
)

;; Submit work
(contract-call? .questchain submit-to-quest
    u1
    "Completed DeFi interface with swap functionality - GitHub: repo-link"
)
```

### SIP-010 Token Quest with Full Categorization
```clarity
;; Create a design quest with tokens
(contract-call? .questchain create-token-quest-with-tags
    "Community Brand Identity"
    "Design complete brand package including logo, colors, and style guide"
    u500000000  ;; 500 tokens (with 6 decimals)
    u2000       ;; Deadline
    u5          ;; Max submissions
    true        ;; Verification required
    .my-token   ;; Token contract trait
    u2          ;; Design category
    (list "branding" "logo" "identity" "graphics" "")  ;; Tags
    "advanced"  ;; Difficulty level
)
```

### Quest Discovery
```clarity
;; Get quest with all categorization info
(contract-call? .questchain get-quest-with-tags u1)

;; Check if quest is in specific category
(contract-call? .questchain is-quest-in-category u1 u1)

;; Check if quest has specific tag
(contract-call? .questchain is-quest-tagged u1 "frontend")

;; Get category details
(contract-call? .questchain get-category u1)
```

## Architecture

### Categories & Tags System
- **Categories**: Hierarchical organization with unique names and descriptions
- **Tags**: Flexible labeling system with up to 5 tags per quest
- **Difficulty Levels**: Standardized four-tier system for skill assessment
- **Indexing**: Efficient lookup tables for category and tag-based filtering
- **Validation**: Comprehensive input validation for all categorization data

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

This implementation provides a robust foundation for a comprehensive quest-based community incentive system with multi-token support, built-in reputation tracking, automated reward distribution, and advanced categorization capabilities.

### Planned Upgrade Features

1. ✅ **Quest Categories & Tags**: Categorization system with filtering capabilities
2. **Team Quests**: Multi-contributor quests with reward splitting mechanisms
3. **Time-Locked Rewards**: Vesting schedules for large quest rewards
4. **Quest Templates**: Pre-built templates for common community tasks
5. **Skill-Based Matching**: Match contributors based on reputation specializations
6. **Quest Dependencies**: Chain quests with prerequisite requirements
7. **Community Voting**: Decentralized verification through voting mechanisms
8. **Achievement Badges**: Specialized NFT badges for contribution types
9. **Cross-Category Analytics**: Advanced metrics and reporting dashboards
10. **Quest Series**: Multi-part quest campaigns with progressive rewards

## Version

**Current Version**: 2.1 - Categories & Tags System

### Changelog
- **v2.1**: Added comprehensive categories and tags system with difficulty levels
- **v2.0**: Multi-token reward support with SIP-010 integration
- **v1.0**: Initial release with STX rewards and reputation system
