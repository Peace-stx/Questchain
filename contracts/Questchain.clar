;; Questchain - Gamified Bounties & Task System for Communities
;; A smart contract-powered quest board for incentivizing community contributions

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

;; Data Variables
(define-data-var quest-counter uint u0)
(define-data-var submission-counter uint u0)
(define-data-var reputation-token-counter uint u0)

;; Data Maps
(define-map quests 
    uint 
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        reward-amount: uint,
        reward-token: principal,
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
    uint ;; total-stx-locked
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

;; Quest Management Functions

(define-public (create-quest 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (reward-amount uint)
    (deadline uint)
    (max-submissions uint)
    (verification-required bool))
    (let 
        (
            (quest-id (+ (var-get quest-counter) u1))
            (current-block burn-block-height)
        )
        ;; Validate inputs
        (asserts! (> (len title) u0) err-invalid-params)
        (asserts! (> (len description) u0) err-invalid-params)
        (asserts! (> reward-amount u0) err-invalid-params)
        (asserts! (> deadline current-block) err-invalid-params)
        (asserts! (> max-submissions u0) err-invalid-params)
        
        ;; Lock STX rewards
        (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
        
        ;; Create quest
        (map-set quests quest-id {
            creator: tx-sender,
            title: title,
            description: description,
            reward-amount: reward-amount,
            reward-token: tx-sender,
            deadline: deadline,
            max-submissions: max-submissions,
            current-submissions: u0,
            status: "active",
            verification-required: verification-required
        })
        
        (map-set quest-rewards quest-id reward-amount)
        (var-set quest-counter quest-id)
        
        (ok quest-id)
    )
)

(define-public (submit-to-quest 
    (quest-id uint)
    (submission-data (string-ascii 500)))
    (let 
        (
            (quest (unwrap! (map-get? quests quest-id) err-not-found))
            (submission-id (+ (var-get submission-counter) u1))
            (current-block burn-block-height)
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

;; Reward Distribution
(define-private (distribute-reward (quest-id uint) (recipient principal))
    (let 
        (
            (quest (unwrap! (map-get? quests quest-id) err-not-found))
            (reward-per-submission (/ (get reward-amount quest) (get max-submissions quest)))
        )
        (as-contract (stx-transfer? reward-per-submission tx-sender recipient))
    )
)

;; Reputation System - Updated to return proper response
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

;; FIXED: Inlined NFT minting logic to avoid parameter passing issues
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
            minted-at: burn-block-height
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
            minted-at: burn-block-height
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

;; Quest Management
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
                (deadline (get deadline quest))
                (max-submissions (get max-submissions quest))
                (current-submissions (get current-submissions quest))
                (status (get status quest))
                (verification-required (get verification-required quest))
            )
                ;; Validate authorization and status
                (asserts! (is-eq tx-sender creator) err-unauthorized)
                (asserts! (is-eq status "active") err-invalid-status)
                
                ;; Get locked rewards
                (match (map-get? quest-rewards quest-id)
                    locked-rewards (begin
                        ;; Update quest status
                        (map-set quests quest-id {
                            creator: creator,
                            title: title,
                            description: description,
                            reward-amount: reward-amount,
                            reward-token: reward-token,
                            deadline: deadline,
                            max-submissions: max-submissions,
                            current-submissions: current-submissions,
                            status: "cancelled",
                            verification-required: verification-required
                        })
                        
                        ;; Refund locked rewards
                        (try! (as-contract (stx-transfer? locked-rewards tx-sender creator)))
                        
                        (ok true)
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