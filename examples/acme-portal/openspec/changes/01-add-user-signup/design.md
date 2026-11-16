# Design: Add user sign-up

## Context
Accounts exist already (sign-in, password reset); support creates them by hand in the back office.

## Decisions

### ADR-001: Verification by link, not by code
A link in the e-mail, valid for 24 hours, verifies the address. A code to type in was considered; a link is
one click for the customer and needs no extra page.

### ADR-002: Unverified accounts are removed after 24 hours
A nightly job removes accounts that were not verified in time, so that an address can be used again.

## Risks / Trade-offs
- E-mails that land in spam: the "check your e-mail" page says so and offers to send the link again.
