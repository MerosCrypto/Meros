### Prerequisites

- Homebrew
- Git
- GCC/G++:
- Make
- CMake _(for RandomX)_
- autoconf / automake / libtool _(for Minisketch)_
- Rust
- choosenim
- Nim 1.2.12

To install every prerequisite, run:

```
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew install git cmake autoconf automake libtool
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
choosenim 1.2.12
```

You will have to update your path after installing Homebrew, Rust, and choosenim. Their installers will say how to.

### Meros

#### Build

```
git clone https://github.com/MerosCrypto/Meros.git
cd Meros
nimble build
```

> There's also a headless version which doesn't import any GUI files available via adding `-d:nogui` to the build command.

#### Run

```
./build/Meros
```
