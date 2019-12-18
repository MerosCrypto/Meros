# Integration Tests

Integration tests written in Python to test Meros's networking code and the RPC.

### Setup

These tests require Python 3.6+ and pip. To install the needed modules:

`pip3 install argon2-cffi ed25519`

They also require the Minisketch and Milagro dynamic libraries. The first should have been built in the process of setting up the `mc_minisketch` Nimble package. Place `libminisketch.so` or `minisketch.dll` under `PythonTests/Libs`. The second needs to be rebuilt by running the following commands from within the `PythonTests/Libs` directory.

```
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
