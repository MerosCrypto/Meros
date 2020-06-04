# Transactions Module

### `getTransaction`

`getTransaction` replies with a Transaction. It takes in one argument:
- Hash (string)

The result is an object, as follows:
- `descendant` (string)

- `inputs` (array of objects, each as follows)
  - `hash` (string)

  	When (`descendant` == "Claim") or (`descendant` == "Send"):
      - `nonce` (int)

- `outputs` (array of objects, each as follows)
  - `amount` (string)

    When `descendant` == "Mint":
    - `key` (int): Miner nickname.

    When `descendant` == "Claim" or `descendant` == "Send":
    - `key` (string): Ed25519 Public Key.

- `hash` (string)

	When `descendant` == "Claim":
  - `signature` (string)

	When `descendant` == "Send":
  - `signature` (string)
  - `proof`     (int)
  - `argon`     (string)

	When `descendant` == "Data":
  - `data`      (string)
  - `signature` (string)
  - `proof`     (int)
  - `argon`     (string)

### `getBalance`

`getBalance` replies with the balance of the specified address. It takes in one argument:
- address (string)

The result is a string of the balance.
