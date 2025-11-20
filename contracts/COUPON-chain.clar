;; coupon.clar
;; Coupon System (simple, clear, Clarinet-ready)
;; - Admin (deployer) can create coupons
;; - Users can redeem a coupon once per coupon-id
;; - Coupons may have max total uses and optional expiry block
;; - Redeeming credits an on-chain points balance (internal ledger)
;; - Storage minimized and checks are explicit for easy reading

;; Error codes (uint)
;; u300 = not-owner
;; u301 = coupon-not-found
;; u302 = coupon-inactive
;; u303 = already-redeemed
;; u304 = coupon-max-uses-reached
;; u305 = coupon-expired
;; u306 = invalid-params

(define-data-var contract-owner principal tx-sender)
(define-data-var coupon-count uint u0)

;; coupons map: key = (id uint)
;; value tuple: (amount uint) (active bool) (max-uses uint) (uses uint) (expires uint)
;; expires = block height after which coupon cannot be redeemed; u0 means no expiry
(define-map coupons
  {id: uint}
  {amount: uint, active: bool, max-uses: uint, uses: uint, expires: uint}
)

;; per-user redemption record: (coupon-id, user) -> (redeemed bool)
(define-map user-redeemed
  {id: uint, user: principal}
  {redeemed: bool}
)

;; internal points ledger: (user) -> (balance uint)
(define-map points
  {user: principal}
  {balance: uint}
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-owner) (ok (var-get contract-owner)))
(define-read-only (get-coupon-count) (ok (var-get coupon-count)))

;; internal: get points balance (uint)
(define-read-only (get-points (who principal))
  (match (map-get? points {user: who})
    entry (ok (get balance entry))
    (ok u0)))

(define-private (set-points (who principal) (amount uint))
  (begin
    (map-set points {user: who} {balance: amount})
    amount))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Admin functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; create a coupon:
;; - amount: points to credit when redeemed (> 0)
;; - max-uses: total times coupon can be redeemed (u0 = unlimited)
;; - expires: block height at which coupon is no longer redeemable (u0 = never expires)
(define-public (create-coupon (amount uint) (max-uses uint) (expires uint))
  (let ((caller tx-sender) (owner (var-get contract-owner)))
    (begin
      (asserts! (is-eq caller owner) (err u300))
      (asserts! (> amount u0) (err u306))
      ;; increment id and store
      (let ((id (var-get coupon-count)))
        (map-set coupons {id: id} {amount: amount, active: true, max-uses: max-uses, uses: u0, expires: expires})
        (var-set coupon-count (+ id u1))
        (ok id)))))

;; deactivate a coupon (admin)
(define-public (deactivate-coupon (id uint))
  (let ((caller tx-sender) (owner (var-get contract-owner)))
    (begin
      (asserts! (is-eq caller owner) (err u300))
      (match (map-get? coupons {id: id})
        coupon
        (let ((amount (get amount coupon)) (max-uses (get max-uses coupon)) (uses (get uses coupon)) (expires (get expires coupon)))
          (begin
            (map-set coupons {id: id} {amount: amount, active: false, max-uses: max-uses, uses: uses, expires: expires})
            (ok true)))
        (err u301)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public user functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Redeem a coupon by id.
;; - Each user may redeem a specific coupon at most once (tracked in `user-redeemed` map).
;; - Coupon must be active, not expired, and must not have exhausted max-uses (if max-uses > 0).
(define-public (redeem (id uint))
  (let ((user tx-sender))
    (match (map-get? coupons {id: id})
      coupon
      (let ((active (get active coupon))
            (amount (get amount coupon))
            (max-uses (get max-uses coupon))
            (uses (get uses coupon))
            (expires (get expires coupon)))
        (begin
          (asserts! (is-eq active true) (err u302))
          ;; <CHANGE> expiry check: use block-height instead of get-block-info
          (asserts! (or (is-eq expires u0) (<= stacks-block-height expires)) (err u305))
          ;; per-user already redeemed?
          (match (map-get? user-redeemed {id: id, user: user})
            some-record (err u303)
            (begin
              ;; max-uses check if max-uses > 0
              (asserts! (or (is-eq max-uses u0) (< uses max-uses)) (err u304))
              ;; mark redeemed
              (map-set user-redeemed {id: id, user: user} {redeemed: true})
              ;; increment uses counter in coupon
              (map-set coupons {id: id} {amount: amount, active: active, max-uses: max-uses, uses: (+ uses u1), expires: expires})
              ;; credit points to user
              (set-points user (+ (match (map-get? points {user: user}) p (get balance p) u0) amount))
              (ok amount)))))
      (err u301))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-only accessors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; <CHANGE> complete the get-coupon function definition
(define-read-only (get-coupon (id uint))
  (match (map-get? coupons {id: id})
    coupon (ok coupon)
    (err u301)))