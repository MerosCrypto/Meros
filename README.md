# <img src="https://github.com/kayabaNerve/Ember/raw/master/logos/logo32.png" height="32px"/> Ember

## An instant and feeless cryptocurrency for the future, secured by the Merit Caching Algorithm.

<a href="https://discord.gg/nZmdWGA"><img src="https://discordapp.com/assets/e05ead6e6ebc08df9291738d0aa6986d.png" height=92 width=92/></a>

[![Gitter Chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/EmberCrypto/Lobby)

### [Outline](https://medium.com/@EmberCrypto/ember-cryptocurrency-d0df75e8170f)
### [Merit Caching Whitepaper](https://github.com/EmberCrypto/Merit-Caching)
### Ember Whitepaper: Being  Written

#### Current State
This currency is not usable by the mass populace. That said, Ember recently had its first transaction! We're aiming to have a private testnet in a few weeks and a public one in a few months.

Only use this software on Linux for now.

#### Compiling

Requirements:

- Nim devel
- Nimble

```
git submodule update --init
nimble install https://github.com/EmberCrypto/BN
nimble install ec_events
nimble install nimcrypto secp256k1 nimx
nim c src/main.nim
```

If you're on Windows:
- Go to https://github.com/Legrandin/mpir-windows-builds and download the GMP dynamic libraries (which you'll have to rename).
- Go to https://www.libsdl.org/download-2.0.php and download the SDL2 dynamic libraries.

If you're on a Debian based system:
```
sudo apt-get install libgmp3-dev
sudo apt-get install libsdl2-2.0
```

For MacOS/other Linux systems, please look up how to install the GMP/SDL2 libraries.

main.nim is blank. There are multiple files that can be swapped out with it under samples/ to test/demo Ember though.

#### Contributing

Ember will not have an ICO, yet the community voted on whether or not there should be a premine. The community decided there should be a seven week premine (Ember doesn't have a max supply, and therefore the premine amount cannot be denominated via a percent). Two weeks will be released at the launch of the network, with one more week released every six months. This will allow a strong mainnet launch, guaranteeing Ember's success, and funding for three years.
