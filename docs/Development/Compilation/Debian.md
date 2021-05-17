### Prerequisites

- Git
- GCC/G++:
- Make
- curl _(for choosenim)_
- CMake _(for RandomX)_
- autoconf / automake / libtool _(for Minisketch)_
- GTK+ 3 and WebKit _(for the GUI)_
- Rust
- choosenim
- Nim 1.2.12

To install every prerequisite, run:

```
sudo apt-get install curl git gcc g++ clang make cmake autoconf automake libtool libwebkit2gtk-4.0-dev libgtksourceview-3.0-dev libappindicator3-dev
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
choosenim 1.2.12
```

You will have to update your path, as according to choosenim, before running any Nim-related commands.

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
