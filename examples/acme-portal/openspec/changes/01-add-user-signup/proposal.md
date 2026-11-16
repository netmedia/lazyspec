# Proposal: Add user sign-up

## Why
Today accounts are created by support. Customers wait up to two days before they can order, and support
spends hours a week on it.

## What Changes
- Customers create their own account with an e-mail address and a password.
- The address is verified through a link sent by e-mail.
- An account that isn't verified within 24 hours is removed.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `user-accounts`: sign-up and e-mail verification.
- `notifications`: the verification e-mail.

## Impact
- API: a sign-up and a verification endpoint.
- Front end: a sign-up page and a "check your e-mail" page.
- Database: the account's verification state (see Models).
