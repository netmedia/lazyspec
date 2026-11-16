# Acme Portal — Overview

## Purpose
Acme Portal is the online shop and customer portal of Acme, a made-up retailer. Customers browse the
catalogue, order and pay online, and follow their orders; Acme's staff manage orders in the back office.

## Requirements

### Requirement: One portal for customers and staff
The portal SHALL serve customers (the shop and their account) and Acme's staff (the back office) from one
system, with each user seeing only what their role allows.

#### Scenario: A customer signs in
- **WHEN** a customer signs in
- **THEN** they see the shop and their own account, not the back office

#### Scenario: Staff sign in
- **WHEN** a member of staff signs in
- **THEN** they see the back office

### Requirement: Supported browsers
The portal SHALL work in the current versions of Chrome, Edge, Firefox and Safari, on desktop and mobile.

#### Scenario: A phone
- **WHEN** a customer opens the shop on a phone
- **THEN** every page is usable without zooming
