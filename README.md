# Ember

## An instant, feeless, lattice stored, PoS verified, PoW blockchain secured cryptocurrency for the future.

### [Outline](https://medium.com/@EmberCrypto/ember-cryptocurrency-d0df75e8170f)
### Whitepaper: Being  Written

#### Current State
This project is not usable. It has secure RNG, SHA512 hashes, Elliptic Curve Keys, Addresses, Lyra2 mining, and the reputation blockchain complete. That said, there's a lot more to do, from the Reputation master file, to the Wallet master file, to the lattice, to the UI, to the network...


#### Compiling

Requirements:

- Nim devel
- Nimble

```
nimble install nimcrypto
nimble install secp256k1
nim c src/main.nim
```
main.nim doesn't do much. There is a miner and address generator under samples/, which are mains that were built to test new code, but are not suitable to be the main file, yet are also not suitable for deletion.

#### Contributing
Ember will not have an ICO. Ember will not have a premine. Ember will be launched publicly and fairly. The only advantage one gets for contributing is being able to get to use the cryptocurrency one day. That said, I would love help and there is a [TODO](https://github.com/kayabaNerve/Ember/blob/master/TODO.md) file.
