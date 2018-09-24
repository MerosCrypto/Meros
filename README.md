# <img src="https://github.com/kayabaNerve/Ember/raw/master/logos/logo32.png" height="32px"/> Ember

## An instant and feeless cryptocurrency for the future, secured by the Merit Caching Algorithm.

<a href="https://discord.gg/nZmdWGA"><img src="https://discordapp.com/assets/e05ead6e6ebc08df9291738d0aa6986d.png" height=92 width=92/></a>

[![Gitter Chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/EmberCrypto/Lobby)

### [Outline](https://medium.com/@EmberCrypto/ember-cryptocurrency-d0df75e8170f)
### [Merit Caching Whitepaper](https://github.com/EmberCrypto/Merit-Caching)
### Ember Whitepaper: Being  Written

#### Current State
This currency is not usable by the mass populace. That said, Ember recently had its first transaction and was able to setup a test network! We're currently working on linking the consensus mechanism.

#### Compiling

Requirements:

- Nim devel
- Nimble

```
git submodule update --init
nimble install https://github.com/EmberCrypto/BN https://github.com/EmberCrypto/SetOnce ec_events
nimble install nimcrypto secp256k1 rocksdb webview
nim c src/main.nim
```

If you're on Windows:
- Go to https://github.com/Legrandin/mpir-windows-builds and download the GMP dynamic libraries (which you'll have to rename).

If you're on a Debian based system:
```
sudo apt-get install libgmp3-dev
```

For MacOS/other Linux systems, please look up how to install the GMP libraries.

There are multiple samples under samples/ that can be directly compiled to demo Ember.

#### Contributing

Ember will not have an ICO, yet the community voted on whether or not there should be a premine. The community decided there should be a seven week premine (Ember doesn't have a max supply, and therefore the premine amount cannot be denominated via a percent). Two weeks will be released at the launch of the network, with one more week released every six months. This will allow a strong mainnet launch, guaranteeing Ember's success, and funding for three years.
