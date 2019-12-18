# This is a guide for any macOS based system.

### Prerequisites

- [Git](https://git-scm.com/downloads)
- GCC/G++:
    - `xcode-select --install`
- Make _(for LMDB)_
    - `xcode-select --install`
- CMake _(for BLS)_
    - via [Homebrew](https://brew.sh/) - `brew install cmake`
- autoconf / automake / libtool _(for Minisketch)_
    - via [Homebrew](https://brew.sh/) - `brew install autoconf automake libtool`
- Choosenim (Nim / Nimble)
    - `curl https://nim-lang.org/choosenim/init.sh -sSf | sh`
- Nim 1.0.4
    - `choosenim 1.0.4`

### Dependencies

To install the Nimble packages:

```shell script
nimble install \
  https://github.com/MerosCrypto/ForceCheck \
  https://github.com/MerosCrypto/Argon2 \
  https://github.com/MerosCrypto/mc_bls \
  https://github.com/MerosCrypto/mc_ed25519 \
  https://github.com/MerosCrypto/mc_pinsketch \
  https://github.com/MerosCrypto/mc_lmdb \
  https://github.com/MerosCrypto/mc_bls \
  https://github.com/MerosCrypto/Nim-Meros-RPC \
  https://github.com/MerosCrypto/mc_webview \
  finals \
  stint \
  nimcrypto \
  normalize
```

For instructions on setting up BLS, see https://github.com/MerosCrypto/mc_bls.

For instructions on setting up Minisketch, see https://github.com/MerosCrypto/mc_pinsketch.

For instructions on setting up LMDB, see https://github.com/MerosCrypto/mc_lmdb.

### Meros

#### Build

```shell script
nim c -f src/main.nim
```

> There's also a headless version which doesn't import any GUI files available via adding `-d:nogui` to the Nim command.

### Run
```shell script
./build/Meros
```