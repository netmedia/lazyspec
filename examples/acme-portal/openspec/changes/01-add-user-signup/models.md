# Models: Add user sign-up

## Overview

| Model / lookup list | Kind | Change | Capabilities |
|---|---|---|---|
| `User` | model | changed | user-accounts |
| `EmailVerification` | model | new | user-accounts, notifications |

## New models

### `EmailVerification`

A link sent to verify a new account's e-mail address.

| Change | Field | Type | Required | Description |
|---|---|---|---|---|
| + | `Id` | `int` | yes | |
| + | `UserId` | `int` | yes | the account it verifies |
| + | `Token` | `string` | yes | the random part of the link |
| + | `ExpiresAt` | `DateTime` | yes | 24 hours after it was sent |
| + | `VerifiedAt` | `DateTime?` | no | when the link was opened |

**Relations:** + `EmailVerification` N:1 `User` (`UserId`)

## Changed models

### `User`

| Change | Field | Type | Required | Description |
|---|---|---|---|---|
| | `Id` | `int` | yes | |
| | `Email` | `string` | yes | |
| + | `IsVerified` | `bool` | yes | false until the address is verified |
| + | `SignedUpAt` | `DateTime?` | no | empty for accounts created by support |
