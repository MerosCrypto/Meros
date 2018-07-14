# <img src="https://github.com/kayabaNerve/Ember/raw/master/logos/logo32.png" height="32px"/> Ember

## An instant, feeless, lattice stored, PoS verified, PoW blockchain secured cryptocurrency for the future.

[![Gitter Chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/EmberCrypto/Lobby)

### [Outline](https://medium.com/@EmberCrypto/ember-cryptocurrency-d0df75e8170f)
### Whitepaper: Being  Written

#### Current State
This project is not usable. It has Base58 and Hexadecimal support, Secure RNG, Elliptic Curve Keys, Addresses, SHA512 hashes, Lyra2 mining, and the Merit Blockchain complete. That said, there's a lot more to do, including the lattice, the UI, the network...

#### Compiling

Requirements:

- Nim devel
- Nimble

```
git submodule update --init
nimble install nimcrypto secp256k1 nimx
nimble install BN
nim c src/main.nim
```
If you're on Windows/Mac OS, you must also go to https://www.libsdl.org/download-2.0.php and download the SDL2 libraries for your platform.
If you're on a Debian based system, run `sudo apt-get install libsdl2-2.0`.
For other Linux systems, please look up how to install the SDL2 libraries.

main.nim doesn't do much. There is a miner and address generator under samples/, which are mains that were built to test new code, but are not suitable to be the main file, yet are also not suitable for deletion. Those should be swapped out with main.nim for testing/demoing Ember.

#### Contributing
Ember will not have an ICO. Ember will not have a premine. Ember will be launched publicly and fairly. The only advantage one gets for contributing is being able to get to use the cryptocurrency one day. That said, I would love help and there is a [TODO](https://github.com/kayabaNerve/Ember/blob/master/TODO.md) file.
