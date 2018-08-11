# <img src="https://github.com/kayabaNerve/Ember/raw/master/logos/logo32.png" height="32px"/> Ember

## An instant and feeless cryptocurrency for the future, secured by the Merit Caching Algorithm.

<a href="https://discord.gg/nZmdWGA"><img src="https://discordapp.com/assets/e05ead6e6ebc08df9291738d0aa6986d.png" height=92 width=92/></a>

[![Gitter Chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/EmberCrypto/Lobby)

### [Outline](https://medium.com/@EmberCrypto/ember-cryptocurrency-d0df75e8170f)
### [Merit Caching Whitepaper](https://github.com/EmberCrypto/Merit-Caching)
### Ember Whitepaper: Being  Written

#### Current State
This currency is not usable. It has a lot done but there's a lot more to do.

#### Compiling

Requirements:

- Nim devel
- Nimble

```
git submodule update --init
nimble install stint nimcrypto secp256k1 nimx
nim cpp src/main.nim
```

If you're on Windows/Mac OS, you must also go to https://www.libsdl.org/download-2.0.php and download the SDL2 libraries for your platform.
If you're on a Debian based system, run `sudo apt-get install libsdl2-2.0`.
For other Linux systems, please look up how to install the SDL2 libraries.

main.nim doesn't do much. There is a miner and address generator under samples/ that can be swapped out with main.nim though in order to test/demo Ember. Right now, main.nim is a demo file for the Lattice.

#### Contributing
Ember will not have an ICO. Ember will not have a premine. Ember will be launched publicly and fairly. The only advantage one gets for contributing is being able to get to use the cryptocurrency one day. That said, I would love help and there is a [TODO](https://github.com/kayabaNerve/Ember/blob/master/TODO.md) file.
