# Integration Tests

Integration tests written in Python to test Meros's networking code and the RPC.

### Setup

These tests require Python 3.6+ and pip. To install the needed modules:

`python3 -m pip install --user argon2-cffi ed25519`

They also require the Minisketch, RandomX, and Milagro shared libraries. Minisketch's should have been built as part of `mc_minisketch`.

- Place `libminisketch.so` (or `minisketch.dll`) from `mc_minisketch` under `PythonTests/Libs`.

RandomX and Milagro need to be built again by running the following commands from within the `PythonTests/Libs` directory.

```
git clone https://github.com/MerosCrypto/mc_randomx
cd mc_randomx
git submodule update --init --recursive
cd RandomX/src
rm configuration.h
rm randomx.h
cp ../../MerosConfiguration/* .
cd ..
mkdir build
cd build
cmake -DARCH=native -DBUILD_SHARED_LIBS=ON ..
make
cd ../../..

git clone https://github.com/apache/incubator-milagro-crypto-c
cd incubator-milagro-crypto-c
mkdir build
cd build
cmake -DAMCL_CURVE=BLS381 ..
make
```

### Static Typing

Meros supports static typing via both Pyright (`pyright -p PythonTests`) and MyPy (`mypy --config-file PythonTests/mypy.ini PythonTests`).

### Linting

Meros supports linting via Pylint (`pylint --rcfile=PythonTests/Pylint/pylintrc PythonTests`).

### Running

`python3.6 -m PythonTests.Test`
