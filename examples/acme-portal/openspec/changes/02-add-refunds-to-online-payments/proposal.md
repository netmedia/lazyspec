# Proposal: Add refunds to online payments

## Why
Refunds are made by hand in the payment provider's dashboard; the portal doesn't know an order was
refunded.

## What Changes
- Staff refund a paid order, or part of it, from the back office.
- The customer sees the refund in their order and gets an e-mail.

## Capabilities

### Modified Capabilities
- `online-payments`: refunds.

## Impact
- API: a refund endpoint; the payment provider's refund API.
