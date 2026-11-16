# Notifications

## Purpose
The e-mails the portal sends to customers about their account and their orders.

## Requirements

### Requirement: Order confirmation e-mail
The system SHALL send the customer an e-mail when their order is confirmed, with the order's items and
total.

#### Scenario: Confirmed order
- **WHEN** an order is confirmed
- **THEN** the customer receives the confirmation e-mail within five minutes
