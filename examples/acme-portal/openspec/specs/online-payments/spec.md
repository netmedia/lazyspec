# Online payments

## Purpose
Customers pay for their orders online by card, through the payment provider.

## Requirements

### Requirement: Card payment
The system SHALL let a customer pay an order by card; the order SHALL be confirmed only after the payment
provider confirms the payment.

#### Scenario: Paid
- **WHEN** the payment provider confirms the payment
- **THEN** the order is confirmed and the customer gets a confirmation e-mail

#### Scenario: Declined
- **WHEN** the card is declined
- **THEN** the order stays open and the customer can try again
