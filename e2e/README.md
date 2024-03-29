# End-to-End Tests

End-to-End tests written in Python to test Meros's networking code and the RPC.

### Setup

First, ensure virtualenv, GMP, MPFR, and MPC are installed. Then, setup the Meros testing environment:

```
virtualenv -p python3.10 ./venv
./venv/bin/pip install -r ./e2e/requirements.txt
```

These tests also require the Minisketch, RandomX, and Milagro shared libraries. Minisketch's should have been built as part of `mc_minisketch`.

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

Meros supports static typing via both Pyright and MyPy:

```
pyright -p e2e
./venv/bin/python3 -m mypy --config-file e2e/mypy.ini e2e
```

### Linting

Meros supports linting via Pylint:

`./venv/bin/python3 -m pylint --rcfile=e2e/MerosPylint/pylintrc e2e`

### Running

From `Meros/` use the following to run all available test cases:

`./venv/bin/python3 -m pytest e2e/Tests/`

Run tests in parallel with 4 workers:

`./venv/bin/python3 -m pytest e2e/Tests/ -n4`

Run a specific test case:

`./venv/bin/python3 -m pytest e2e/Tests/ -k "ChainAdvancement"`
