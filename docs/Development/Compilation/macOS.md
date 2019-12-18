### Prerequisites

- Homebrew
- Git
- GCC/G++:
- Make
- CMake _(for BLS)_
- autoconf / automake / libtool _(for Minisketch)_
- choosenim
- Nim 1.0.4

To install every prerequisite, run:

```
xcode-select --install
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install git cmake autoconf automake libtool
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
choosenim 1.0.4
```

### Libraries

To install the Nimble packages:

```
nimble install https://github.com/MerosCrypto/ForceCheck https://github.com/MerosCrypto/Argon2 https://github.com/MerosCrypto/mc_bls https://github.com/MerosCrypto/mc_ed25519 https://github.com/MerosCrypto/mc_pinsketch https://github.com/MerosCrypto/mc_lmdb https://github.com/MerosCrypto/Nim-Meros-RPC https://github.com/MerosCrypto/mc_webview finals stint nimcrypto normalize
```

For instructions on setting up Minisketch, see https://github.com/MerosCrypto/mc_pinsketch.

For instructions on setting up LMDB, see https://github.com/MerosCrypto/mc_lmdb.

### Meros

#### Build

```
git clone https://github.com/MerosCrypto/Meros.git
cd Meros
nim c src/main.nim
```

> There's also a headless version which doesn't import any GUI files available via adding `-d:nogui` to the build command.

#### Run

```
./build/Meros
```
