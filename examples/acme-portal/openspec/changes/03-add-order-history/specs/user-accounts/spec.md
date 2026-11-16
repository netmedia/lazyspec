## ADDED Requirements

### Requirement: Order history
The system SHALL show a signed-in customer their orders, newest first, with each order's date, status and
total.

#### Scenario: Orders
- **WHEN** a customer with orders opens "Orders"
- **THEN** they see every order, newest first

#### Scenario: No orders yet
- **WHEN** a customer without orders opens "Orders"
- **THEN** they see that there are no orders yet and a link to the shop
