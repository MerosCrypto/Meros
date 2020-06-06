# End-to-End Tests

End-to-End tests written in Python to test Meros's networking code and the RPC.

### Setup

These tests require Python 3.6+ and pip. To install the needed modules:

`python3 -m pip install --user argon2-cffi ed25519 bip-utils`

They also require the Minisketch, RandomX, and Milagro shared libraries. Minisketch's should have been built as part of `mc_minisketch`.

- Place `libminisketch.so` (or `minisketch.dll`) from `mc_minisketch` under `e2e/Libs`.

RandomX and Milagro need to be built again by running the following commands from within the `e2e/Libs` directory.

```
git clone https://github.com/MerosCrypto/mc_randomx
cd mc_randomx
git submodule update --init --recursive
cd RandomX/src
rm configuration.h
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

Meros supports static typing via both Pyright (`pyright -p e2e`) and MyPy (`mypy --config-file e2e/mypy.ini e2e`).

### Linting

Meros supports linting via Pylint (`pylint --rcfile=e2e/Pylint/pylintrc e2e`).

### Running

`python3.6 -m e2e.Test`
