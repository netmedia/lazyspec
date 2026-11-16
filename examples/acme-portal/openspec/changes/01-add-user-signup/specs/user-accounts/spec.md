## ADDED Requirements

### Requirement: Self sign-up
The system SHALL let a visitor create an account with an e-mail address and a password of at least 12
characters.

#### Scenario: New address
- **WHEN** a visitor signs up with an address that has no account
- **THEN** an account is created and a verification e-mail is sent

#### Scenario: Address in use
- **WHEN** a visitor signs up with an address that already has an account
- **THEN** the visitor sees the same "check your e-mail" page, and the owner of the address gets an e-mail saying someone tried to sign up

### Requirement: E-mail verification
The system SHALL let a new account sign in only after its e-mail address is verified through the link.

#### Scenario: Link opened in time
- **WHEN** the customer opens the link within 24 hours
- **THEN** the account is verified and the customer is signed in

#### Scenario: Link expired
- **WHEN** the customer opens the link after 24 hours
- **THEN** they see that the link expired and can sign up again
