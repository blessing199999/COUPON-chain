COUPON-chain

A simple, clear, and Clarinet-ready coupon system smart contract for the Stacks blockchain, written in Clarity.

Features
Admin (deployer) can create coupons
Users can redeem a coupon once per coupon-id
Coupons may have max total uses and optional expiry block
Redeeming credits an on-chain points balance (internal ledger)
Explicit checks and minimized storage for easy reading
Data Structures
Coupons Map:
Stores coupon details by ID:
{amount: uint, active: bool, max-uses: uint, uses: uint, expires: uint}

User Redemption Map:
Tracks if a user has redeemed a coupon:
{id: uint, user: principal} -> {redeemed: bool}

Points Ledger:
Tracks user points:
{user: principal} -> {balance: uint}

Error Codes
Code	Meaning
u300	Not owner
u301	Coupon not found
u302	Coupon inactive
u303	Already redeemed
u304	Coupon max uses reached
u305	Coupon expired
u306	Invalid parameters
Functions
Admin Functions
create-coupon(amount, max-uses, expires)
Create a new coupon. Only contract owner can call.

deactivate-coupon(id)
Deactivate a coupon. Only contract owner can call.

User Functions
redeem(id)
Redeem a coupon by ID.
Only one redemption per user per coupon.
Checks for active status, expiry, and max uses.
Read-Only Functions
get-owner()
Returns contract owner.

get-coupon-count()
Returns total number of coupons created.

get-points(who)
Returns points balance for a user.

get-coupon(id)
Returns coupon details by ID.

Usage
Deploy the contract using Clarinet or compatible Stacks tools.
Admin functions require the contract deployer as caller.

Notes
Coupon expiry is checked against the current block height.
Points are credited to users upon successful redemption.
All checks are explicit for clarity and security.
