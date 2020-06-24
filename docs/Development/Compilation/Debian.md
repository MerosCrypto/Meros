### Prerequisites

- Git
- GCC/G++:
- Make
- curl _(for choosenim)_
- CMake _(for BLS)_
- autoconf / automake / libtool _(for Minisketch)_
- GTK+ 3 and WebKit _(for the GUI)_
- Python 3.6 and Pip _(for the tests)_
- choosenim
- Nim 1.2.0

To install every prerequisite, run:

```
sudo apt-get install git gcc g++ make cmake autoconf automake libtool gtk+-3.0 at-spi2-core webkit2gtk-4.0 curl python3 python3-pip virtualenv
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
choosenim 1.2.0
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
