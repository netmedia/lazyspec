# User accounts

## Purpose
Customers have an account with an e-mail address and a password, so that they can order faster and follow
their orders.

## Requirements

### Requirement: Sign in
The system SHALL let a customer sign in with their e-mail address and password.

#### Scenario: Valid password
- **WHEN** the customer enters their e-mail address and the right password
- **THEN** they are signed in

#### Scenario: Wrong password
- **WHEN** the password is wrong
- **THEN** the customer sees an error and stays signed out

### Requirement: Password reset
The system SHALL let a customer set a new password through a link sent to their e-mail address.

#### Scenario: Reset link
- **WHEN** the customer asks for a reset link
- **THEN** a link valid for one hour is sent to their address
