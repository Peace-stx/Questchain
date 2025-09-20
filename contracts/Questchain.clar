;; Questchain - Gamified Bounties & Task System for Communities
;; A smart contract-powered quest board for incentivizing community contributions
;; Version 2.1 - Categories & Tags System

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-quest-expired (err u104))
(define-constant err-insufficient-rewards (err u105))
(define-constant err-already-completed (err u106))
(define-constant err-invalid-status (err u107))
(define-constant err-unsupported-token (err u108))
(define-constant err-token-transfer-failed (err u109))
(define-constant err-category-not-found (err u110))
(define-constant err-invalid-tags (err u111))

;; Token type constants
(define-constant token-type-stx "STX")
(define-constant token-type-sip010 "SIP010")

;; Data Variables
(define-data-var quest-counter uint u0)
(define-data-var submission-counter uint u0)
(define-data-var reputation-token-counter uint u0)
(define-data-var category-counter uint u0)

;; Categories and Tags Maps
(define-map quest-categories
    uint ;; category-id
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        enabled: bool,
        created-by: principal,
        quest-count: uint
    }
)

(define-map category-name-to-id
    (string-ascii 50) ;; category name
    uint ;; category-id
)

(define-map quest-tags
    uint ;; quest-id
    {
        category-id: uint,
        tags: (list 5 (string-ascii 30)),
        difficulty: (string-ascii 20) ;; "beginner", "intermediate", "advanced", "expert"
    }
)

(define-map category-quests
    {category-id: uint, quest-id: uint}
    bool ;; exists flag
)

(define-map tag-quests
    {tag: (string-ascii 30), quest-id: uint}
    bool ;; exists flag
)

;; Supported token contracts - stores trait references
(define-map supported-tokens 
    principal 
    {
        enabled: bool,
        token-name: (string-ascii 32),
        token-symbol: (string-ascii 10),
        decimals: uint
    }
)

;; Data Maps
(define-map quests 
    uint 
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        reward-amount: uint,
        reward-token: principal,
        token-type: (string-ascii 10),
        deadline: uint,
        max-submissions: uint,
        current-submissions: uint,
        status: (string-ascii 20), ;; "active", "completed", "cancelled"
        verification-required: bool
    }
)

(define-map submissions
    uint
    {
        quest-id: uint,
        submitter: principal,
        submission-data: (string-ascii 500),
        status: (string-ascii 20), ;; "pending", "approved", "rejected"
        submitted-at: uint,
        verified-by: (optional principal)
    }
)

(define-map user-submissions
    {user: principal, quest-id: uint}
    uint ;; submission-id
)

(define-map quest-rewards
    uint ;; quest-id
    {
        total-locked: uint,
        token-contract: principal,
        token-type: (string-ascii 10)
    }
)

(define-map user-reputation
    principal
    {
        total-quests-completed: uint,
        reputation-score: uint,
        nft-count: uint
    }
)

(define-map reputation-nfts
    uint ;; nft-id
    {
        owner: principal,
        reputation-level: uint,
        quest-count: uint,
        minted-at: uint
    }
)

;; SIP-010 Trait Definition
(define-trait sip010-token
    (
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 32) uint))
        (get-decimals () (response uint uint))
        (get-balance (principal) (response uint uint))
        (set-token-uri ((optional (string-utf8 256))) (response bool uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-total-supply () (response uint uint))
    )
)

;; Category Management Functions
(define-public (create-category 
    (name (string-ascii 50))
    (description (string-ascii 200)))
    (let 
        (
            (category-id (+ (var-get category-counter) u1))
            (name-length (len name))
            (desc-length (len description))
        )
        ;; Validate inputs
        (asserts! (> name-length u0) err-invalid-params)
        (asserts! (<= name-length u50) err-invalid-params)
        (asserts! (> desc-length u0) err-invalid-params)
        (asserts! (<= desc-length u200) err-invalid-params)
        (asserts! (is-none (map-get? category-name-to-id name)) err-invalid-params)
        
        ;; Create category
        (map-set quest-categories category-id {
            name: name,
            description: description,
            enabled: true,
            created-by: tx-sender,
            quest-count: u0
        })
        
        (map-set category-name-to-id name category-id)
        (var-set category-counter category-id)
        (ok category-id)
    )
)

(define-public (toggle-category (category-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> category-id u0) err-invalid-params)
        
        (match (map-get? quest-categories category-id)
            category (begin
                (map-set quest-categories category-id 
                    (merge category {enabled: (not (get enabled category))}))
                (ok true)
            )
            err-category-not-found
        )
    )
)

;; Helper Functions
(define-private (is-token-supported (token-contract principal))
    (match (map-get? supported-tokens token-contract)
        token-info (get enabled token-info)
        false
    )
)

(define-private (is-category-valid (category-id uint))
    (match (map-get? quest-categories category-id)
        category (get enabled category)
        false
    )
)

(define-private (validate-tags (tags (list 5 (string-ascii 30))))
    (fold validate-single-tag tags true)
)

(define-private (validate-single-tag (tag (string-ascii 30)) (acc bool))
    (and acc 
         (> (len tag) u0)
         (<= (len tag) u30))
)

(define-private (validate-difficulty (difficulty (string-ascii 20)))
    (or 
        (is-eq difficulty "beginner")
        (is-eq difficulty "intermediate") 
        (is-eq difficulty "advanced")
        (is-eq difficulty "expert")
    )
)

(define-private (validate-quest-params 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (reward-amount uint)
    (deadline uint)
    (max-submissions uint))
    (let ((current-block stacks-block-height))
        (and
            (> (len title) u0)
            (> (len description) u0)
            (> reward-amount u0)
            (> deadline current-block)
            (> max-submissions u0)
            (<= max-submissions u50) ;; reasonable limit
        )
    )
)

(define-private (increment-category-quest-count (category-id uint))
    (match (map-get? quest-categories category-id)
        category (begin
            (map-set quest-categories category-id 
                (merge category {quest-count: (+ (get quest-count category) u1)}))
            true
        )
        false
    )
)

(define-private (add-quest-to-indexes 
    (quest-id uint)
    (category-id uint)
    (tags (list 5 (string-ascii 30))))
    (begin
        ;; Add to category index
        (map-set category-quests {category-id: category-id, quest-id: quest-id} true)
        
        ;; Add to tag indexes
        (fold add-tag-index tags quest-id)
        true
    )
)

(define-private (add-tag-index (tag (string-ascii 30)) (quest-id uint))
    (begin
        (if (> (len tag) u0)
            (map-set tag-quests {tag: tag, quest-id: quest-id} true)
            false
        )
        quest-id
    )
)

;; Admin Functions for Token Management
(define-public (add-supported-token 
    (token-contract principal)
    (token-name (string-ascii 32))
    (token-symbol (string-ascii 10))
    (decimals uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-standard token-contract) err-invalid-params)
        (asserts! (> (len token-name) u0) err-invalid-params)
        (asserts! (> (len token-symbol) u0) err-invalid-params)
        (asserts! (<= decimals u18) err-invalid-params)
        
        (map-set supported-tokens token-contract {
            enabled: true,
            token-name: token-name,
            token-symbol: token-symbol,
            decimals: decimals
        })
        (ok true)
    )
)

(define-public (toggle-token-support (token-contract principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-standard token-contract) err-invalid-params)
        
        (match (map-get? supported-tokens token-contract)
            token-info (begin
                (map-set supported-tokens token-contract 
                    (merge token-info {enabled: (not (get enabled token-info))}))
                (ok true)
            )
            err-not-found
        )
    )
)

;; Enhanced Quest Management Functions

;; Create quest with STX rewards and categories/tags
(define-public (create-stx-quest-with-tags
    (title (string-ascii 100))
    (description (string-ascii 500))
    (reward-amount uint)
    (deadline uint)
    (max-submissions uint)
    (verification-required bool)
    (category-id uint)
    (tags (list 5 (string-ascii 30)))
    (difficulty (string-ascii 20)))
    (let 
        (
            (quest-id (+ (var-get quest-counter) u1))
            (current-block stacks-block-height)
        )
        ;; Validate inputs
        (asserts! (validate-quest-params title description reward-amount deadline max-submissions) err-invalid-params)
        (asserts! (is-category-valid category-id) err-category-not-found)
        (asserts! (validate-tags tags) err-invalid-tags)
        (asserts! (validate-difficulty difficulty) err-invalid-params)
        
        ;; Lock STX rewards
        (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
        
        ;; Create quest
        (map-set quests quest-id {
            creator: tx-sender,
            title: title,
            description: description,
            reward-amount: reward-amount,
            reward-token: tx-sender,
            token-type: token-type-stx,
            deadline: deadline,
            max-submissions: max-submissions,
            current-submissions: u0,
            status: "active",
            verification-required: verification-required
        })
        
        (map-set quest-rewards quest-id {
            total-locked: reward-amount,
            token-contract: tx-sender,
            token-type: token-type-stx
        })
        
        ;; Add tags and category info
        (map-set quest-tags quest-id {
            category-id: category-id,
            tags: tags,
            difficulty: difficulty
        })
        
        ;; Update indexes
        (increment-category-quest-count category-id)
        (add-quest-to-indexes quest-id category-id tags)
        
        (var-set quest-counter quest-id)
        (ok quest-id)
    )
)

;; Create quest with SIP-010 token rewards and categories/tags
(define-public (create-token-quest-with-tags
    (title (string-ascii 100))
    (description (string-ascii 500))
    (reward-amount uint)
    (deadline uint)
    (max-submissions uint)
    (verification-required bool)
    (token-contract <sip010-token>)
    (category-id uint)
    (tags (list 5 (string-ascii 30)))
    (difficulty (string-ascii 20)))
    (let 
        (
            (quest-id (+ (var-get quest-counter) u1))
            (current-block stacks-block-height)
            (token-principal (contract-of token-contract))
        )
        ;; Validate inputs
        (asserts! (validate-quest-params title description reward-amount deadline max-submissions) err-invalid-params)
        (asserts! (is-token-supported token-principal) err-unsupported-token)
        (asserts! (is-category-valid category-id) err-category-not-found)
        (asserts! (validate-tags tags) err-invalid-tags)
        (asserts! (validate-difficulty difficulty) err-invalid-params)
        
        ;; Lock token rewards by transferring to contract
        (try! (contract-call? token-contract transfer reward-amount tx-sender (as-contract tx-sender) none))
        
        ;; Create quest
        (map-set quests quest-id {
            creator: tx-sender,
            title: title,
            description: description,
            reward-amount: reward-amount,
            reward-token: token-principal,
            token-type: token-type-sip010,
            deadline: deadline,
            max-submissions: max-submissions,
            current-submissions: u0,
            status: "active",
            verification-required: verification-required
        })
        
        (map-set quest-rewards quest-id {
            total-locked: reward-amount,
            token-contract: token-principal,
            token-type: token-type-sip010
        })
        
        ;; Add tags and category info
        (map-set quest-tags quest-id {
            category-id: category-id,
            tags: tags,
            difficulty: difficulty
        })
        
        ;; Update indexes
        (increment-category-quest-count category-id)
        (add-quest-to-indexes quest-id category-id tags)
        
        (var-set quest-counter quest-id)
        (ok quest-id)
    )
)

;; Create quest with STX rewards
(define-public (create-stx-quest 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (reward-amount uint)
    (deadline uint)
    (max-submissions uint)
    (verification-required bool))
    (let 
        (
            (quest-id (+ (var-get quest-counter) u1))
            (current-block stacks-block-height)
        )
        ;; Validate inputs
        (asserts! (validate-quest-params title description reward-amount deadline max-submissions) err-invalid-params)
        
        ;; Lock STX rewards
        (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
        
        ;; Create quest
        (map-set quests quest-id {
            creator: tx-sender,
            title: title,
            description: description,
            reward-amount: reward-amount,
            reward-token: tx-sender,
            token-type: token-type-stx,
            deadline: deadline,
            max-submissions: max-submissions,
            current-submissions: u0,
            status: "active",
            verification-required: verification-required
        })
        
        (map-set quest-rewards quest-id {
            total-locked: reward-amount,
            token-contract: tx-sender,
            token-type: token-type-stx
        })
        
        (var-set quest-counter quest-id)
        (ok quest-id)
    )
)

;; Create quest with SIP-010 token rewards
(define-public (create-token-quest
    (title (string-ascii 100))
    (description (string-ascii 500))
    (reward-amount uint)
    (deadline uint)
    (max-submissions uint)
    (verification-required bool)
    (token-contract <sip010-token>))
    (let 
        (
            (quest-id (+ (var-get quest-counter) u1))
            (current-block stacks-block-height)
            (token-principal (contract-of token-contract))
        )
        ;; Validate inputs
        (asserts! (validate-quest-params title description reward-amount deadline max-submissions) err-invalid-params)
        (asserts! (is-token-supported token-principal) err-unsupported-token)
        
        ;; Lock token rewards by transferring to contract
        (try! (contract-call? token-contract transfer reward-amount tx-sender (as-contract tx-sender) none))
        
        ;; Create quest
        (map-set quests quest-id {
            creator: tx-sender,
            title: title,
            description: description,
            reward-amount: reward-amount,
            reward-token: token-principal,
            token-type: token-type-sip010,
            deadline: deadline,
            max-submissions: max-submissions,
            current-submissions: u0,
            status: "active",
            verification-required: verification-required
        })
        
        (map-set quest-rewards quest-id {
            total-locked: reward-amount,
            token-contract: token-principal,
            token-type: token-type-sip010
        })
        
        (var-set quest-counter quest-id)
        (ok quest-id)
    )
)

;; Backward compatibility - original create-quest function defaults to STX
(define-public (create-quest 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (reward-amount uint)
    (deadline uint)
    (max-submissions uint)
    (verification-required bool))
    (create-stx-quest title description reward-amount deadline max-submissions verification-required)
)

(define-public (submit-to-quest 
    (quest-id uint)
    (submission-data (string-ascii 500)))
    (let 
        (
            (quest (unwrap! (map-get? quests quest-id) err-not-found))
            (submission-id (+ (var-get submission-counter) u1))
            (current-block stacks-block-height)
            (user-key {user: tx-sender, quest-id: quest-id})
        )
        ;; Validate quest and submission
        (asserts! (is-eq (get status quest) "active") err-invalid-status)
        (asserts! (< current-block (get deadline quest)) err-quest-expired)
        (asserts! (< (get current-submissions quest) (get max-submissions quest)) err-invalid-params)
        (asserts! (is-none (map-get? user-submissions user-key)) err-already-completed)
        (asserts! (> (len submission-data) u0) err-invalid-params)
        
        ;; Create submission
        (map-set submissions submission-id {
            quest-id: quest-id,
            submitter: tx-sender,
            submission-data: submission-data,
            status: "pending",
            submitted-at: current-block,
            verified-by: none
        })
        
        ;; Update quest submission count
        (map-set quests quest-id 
            (merge quest {current-submissions: (+ (get current-submissions quest) u1)})
        )
        
        ;; Track user submission
        (map-set user-submissions user-key submission-id)
        (var-set submission-counter submission-id)
        
        ;; Auto-approve if verification not required
        (if (not (get verification-required quest))
            (begin
                (try! (approve-submission submission-id))
                (ok submission-id)
            )
            (ok submission-id)
        )
    )
)

(define-public (approve-submission (submission-id uint))
    (let 
        (
            (submission (unwrap! (map-get? submissions submission-id) err-not-found))
            (quest (unwrap! (map-get? quests (get quest-id submission)) err-not-found))
        )
        ;; Validate authorization
        (asserts! (or 
            (is-eq tx-sender (get creator quest))
            (is-eq tx-sender contract-owner)
        ) err-unauthorized)
        (asserts! (is-eq (get status submission) "pending") err-invalid-status)
        
        ;; Update submission status
        (map-set submissions submission-id 
            (merge submission {
                status: "approved",
                verified-by: (some tx-sender)
            })
        )
        
        ;; Distribute rewards
        (try! (distribute-reward (get quest-id submission) (get submitter submission)))
        
        ;; Update user reputation and return success
        (let ((reputation-result (update-user-reputation (get submitter submission))))
            (ok true)
        )
    )
)

(define-public (reject-submission (submission-id uint))
    (let 
        (
            (submission (unwrap! (map-get? submissions submission-id) err-not-found))
            (quest (unwrap! (map-get? quests (get quest-id submission)) err-not-found))
        )
        ;; Validate authorization
        (asserts! (or 
            (is-eq tx-sender (get creator quest))
            (is-eq tx-sender contract-owner)
        ) err-unauthorized)
        (asserts! (is-eq (get status submission) "pending") err-invalid-status)
        
        ;; Update submission status
        (map-set submissions submission-id 
            (merge submission {
                status: "rejected",
                verified-by: (some tx-sender)
            })
        )
        
        (ok true)
    )
)

;; Enhanced Reward Distribution - STX Only Version
(define-private (distribute-reward (quest-id uint) (recipient principal))
    (let 
        (
            (quest (unwrap! (map-get? quests quest-id) err-not-found))
            (quest-reward-info (unwrap! (map-get? quest-rewards quest-id) err-not-found))
            (reward-per-submission (/ (get reward-amount quest) (get max-submissions quest)))
            (token-type (get token-type quest-reward-info))
        )
        (if (is-eq token-type token-type-stx)
            ;; Distribute STX rewards
            (as-contract (stx-transfer? reward-per-submission tx-sender recipient))
            ;; For SIP-010 tokens, currently not supported in this simplified version
            ;; This would need to be implemented with specific token contracts
            err-unsupported-token
        )
    )
)

;; Separate public functions for SIP-010 reward distribution
;; These functions allow for specific token contract implementation

(define-public (distribute-sip010-reward-with-trait
    (quest-id uint)
    (recipient principal)
    (token-contract <sip010-token>))
    (let 
        (
            (quest (unwrap! (map-get? quests quest-id) err-not-found))
            (quest-reward-info (unwrap! (map-get? quest-rewards quest-id) err-not-found))
            (reward-per-submission (/ (get reward-amount quest) (get max-submissions quest)))
            (token-principal (contract-of token-contract))
        )
        ;; Validate authorization (only contract or quest creator)
        (asserts! (or 
            (is-eq tx-sender contract-owner)
            (is-eq tx-sender (get creator quest))
        ) err-unauthorized)
        
        ;; Validate token contract matches quest
        (asserts! (is-eq token-principal (get token-contract quest-reward-info)) err-invalid-params)
        
        ;; Transfer tokens
        (as-contract 
            (contract-call? token-contract transfer reward-per-submission tx-sender recipient none)
        )
    )
)

;; Reputation System
(define-private (update-user-reputation (user principal))
    (let 
        (
            (current-rep (default-to {total-quests-completed: u0, reputation-score: u0, nft-count: u0} 
                                   (map-get? user-reputation user)))
            (new-completed (+ (get total-quests-completed current-rep) u1))
            (new-score (+ (get reputation-score current-rep) u10))
        )
        (map-set user-reputation user {
            total-quests-completed: new-completed,
            reputation-score: new-score,
            nft-count: (get nft-count current-rep)
        })
        
        ;; Mint reputation NFT at milestones
        (if (is-eq (mod new-completed u5) u0) ;; Every 5 completed quests
            (begin
                (mint-reputation-nft-internal user new-completed)
                true
            )
            true
        )
    )
)

;; NFT minting logic
(define-private (mint-reputation-nft-internal (recipient principal) (quest-count uint))
    (let 
        (
            (nft-id (+ (var-get reputation-token-counter) u1))
            (reputation-level (/ quest-count u5))
            (default-rep {total-quests-completed: u0, reputation-score: u0, nft-count: u0})
            (existing-rep (default-to default-rep (map-get? user-reputation recipient)))
            (total-completed (get total-quests-completed existing-rep))
            (rep-score (get reputation-score existing-rep))
            (current-nft-count (get nft-count existing-rep))
        )
        ;; Create NFT record
        (map-set reputation-nfts nft-id {
            owner: recipient,
            reputation-level: reputation-level,
            quest-count: quest-count,
            minted-at: stacks-block-height
        })
        
        ;; Update user reputation NFT count with validated data
        (map-set user-reputation recipient {
            total-quests-completed: total-completed,
            reputation-score: rep-score,
            nft-count: (+ current-nft-count u1)
        })
        
        ;; Update counter and return the new NFT ID
        (var-set reputation-token-counter nft-id)
        nft-id
    )
)

;; Public function for manual NFT minting (admin only)
(define-public (admin-mint-reputation-nft (recipient principal) (quest-count uint))
    (let 
        (
            (nft-id (+ (var-get reputation-token-counter) u1))
            (reputation-level (/ quest-count u5))
            (default-rep {total-quests-completed: u0, reputation-score: u0, nft-count: u0})
            (existing-rep (default-to default-rep (map-get? user-reputation recipient)))
            (total-completed (get total-quests-completed existing-rep))
            (rep-score (get reputation-score existing-rep))
            (current-nft-count (get nft-count existing-rep))
        )
        ;; Validate authorization and inputs
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> quest-count u0) err-invalid-params)
        (asserts! (is-standard recipient) err-invalid-params)
        
        ;; Create NFT record
        (map-set reputation-nfts nft-id {
            owner: recipient,
            reputation-level: reputation-level,
            quest-count: quest-count,
            minted-at: stacks-block-height
        })
        
        ;; Update user reputation NFT count with validated data
        (map-set user-reputation recipient {
            total-quests-completed: total-completed,
            reputation-score: rep-score,
            nft-count: (+ current-nft-count u1)
        })
        
        (var-set reputation-token-counter nft-id)
        (ok nft-id)
    )
)

;; Enhanced Quest Management
(define-public (cancel-quest (quest-id uint))
    (begin
        ;; Validate inputs first
        (asserts! (> quest-id u0) err-invalid-params)
        
        ;; Get quest and extract all fields immediately
        (match (map-get? quests quest-id)
            quest (let (
                (creator (get creator quest))
                (title (get title quest))
                (description (get description quest))
                (reward-amount (get reward-amount quest))
                (reward-token (get reward-token quest))
                (token-type (get token-type quest))
                (deadline (get deadline quest))
                (max-submissions (get max-submissions quest))
                (current-submissions (get current-submissions quest))
                (status (get status quest))
                (verification-required (get verification-required quest))
            )
                ;; Validate authorization and status
                (asserts! (is-eq tx-sender creator) err-unauthorized)
                (asserts! (is-eq status "active") err-invalid-status)
                
                ;; Get locked rewards and refund based on token type
                (match (map-get? quest-rewards quest-id)
                    reward-info (let (
                        (locked-amount (get total-locked reward-info))
                        (reward-token-type (get token-type reward-info))
                    )
                        ;; Update quest status
                        (map-set quests quest-id {
                            creator: creator,
                            title: title,
                            description: description,
                            reward-amount: reward-amount,
                            reward-token: reward-token,
                            token-type: token-type,
                            deadline: deadline,
                            max-submissions: max-submissions,
                            current-submissions: current-submissions,
                            status: "cancelled",
                            verification-required: verification-required
                        })
                        
                        ;; Refund STX rewards only (SIP-010 refunds need manual handling)
                        (if (is-eq reward-token-type token-type-stx)
                            (try! (as-contract (stx-transfer? locked-amount tx-sender creator)))
                            true ;; SIP-010 refunds would need to be handled separately
                        )
                        
                        (ok true)
                    )
                    err-not-found
                )
            )
            err-not-found
        )
    )
)

;; Separate function for cancelling SIP-010 token quests with refund
(define-public (cancel-sip010-quest-with-refund 
    (quest-id uint)
    (token-contract <sip010-token>))
    (begin
        ;; Validate inputs first
        (asserts! (> quest-id u0) err-invalid-params)
        
        ;; Get quest and extract all fields immediately
        (match (map-get? quests quest-id)
            quest (let (
                (creator (get creator quest))
                (token-principal (contract-of token-contract))
            )
                ;; Validate authorization and status
                (asserts! (is-eq tx-sender creator) err-unauthorized)
                (asserts! (is-eq (get status quest) "active") err-invalid-status)
                
                ;; Get locked rewards
                (match (map-get? quest-rewards quest-id)
                    reward-info (let (
                        (locked-amount (get total-locked reward-info))
                        (reward-token-contract (get token-contract reward-info))
                    )
                        ;; Validate token contract matches
                        (asserts! (is-eq token-principal reward-token-contract) err-invalid-params)
                        
                        ;; Update quest status to cancelled
                        (map-set quests quest-id 
                            (merge quest {status: "cancelled"}))
                        
                        ;; Refund SIP-010 tokens
                        (as-contract 
                            (contract-call? token-contract transfer locked-amount tx-sender creator none)
                        )
                    )
                    err-not-found
                )
            )
            err-not-found
        )
    )
)

;; Read-only functions
(define-read-only (get-quest (quest-id uint))
    (map-get? quests quest-id)
)

(define-read-only (get-quest-with-reward-info (quest-id uint))
    (match (map-get? quests quest-id)
        quest (match (map-get? quest-rewards quest-id)
            reward-info (ok {
                quest: quest,
                reward-info: reward-info
            })
            err-not-found
        )
        err-not-found
    )
)

(define-read-only (get-quest-with-tags (quest-id uint))
    (match (map-get? quests quest-id)
        quest (ok {
            quest: quest,
            tags: (map-get? quest-tags quest-id)
        })
        err-not-found
    )
)

(define-read-only (get-category (category-id uint))
    (map-get? quest-categories category-id)
)

(define-read-only (get-category-by-name (name (string-ascii 50)))
    (match (map-get? category-name-to-id name)
        category-id (map-get? quest-categories category-id)
        none
    )
)

(define-read-only (get-quest-tags (quest-id uint))
    (map-get? quest-tags quest-id)
)

(define-read-only (is-quest-in-category (quest-id uint) (category-id uint))
    (is-some (map-get? category-quests {category-id: category-id, quest-id: quest-id}))
)

(define-read-only (is-quest-tagged (quest-id uint) (tag (string-ascii 30)))
    (is-some (map-get? tag-quests {tag: tag, quest-id: quest-id}))
)

(define-read-only (get-submission (submission-id uint))
    (map-get? submissions submission-id)
)

(define-read-only (get-user-reputation (user principal))
    (map-get? user-reputation user)
)

(define-read-only (get-user-submission (user principal) (quest-id uint))
    (map-get? user-submissions {user: user, quest-id: quest-id})
)

(define-read-only (get-reputation-nft (nft-id uint))
    (map-get? reputation-nfts nft-id)
)

(define-read-only (get-quest-count)
    (var-get quest-counter)
)

(define-read-only (get-submission-count)
    (var-get submission-counter)
)

(define-read-only (get-category-count)
    (var-get category-counter)
)

(define-read-only (get-supported-token (token-contract principal))
    (map-get? supported-tokens token-contract)
)

(define-read-only (is-token-enabled (token-contract principal))
    (match (map-get? supported-tokens token-contract)
        token-info (get enabled token-info)
        false
    )
)