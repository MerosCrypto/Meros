# Integration Tests

Integration tests written in Python to test Meros's networking code and the RPC.

### Setup

These tests require Python 3.6+ and pip. To install the needed modules:

`pip3 install argon2-cffi ed25519 blspy`

They also require the Minisketch dynamic library, which should've been built in the process of setting up the `mc_pinsketch` Nimble package. Place `libminisketch.so` or `minisketch.dll` under `PythonTests/Stubs`.

### Static Typing

Meros supports static typing via both Pyright (`pyright -p PythonTests`) and MyPy (`mypy --config-file PythonTests/mypy.ini --namespace-packages PythonTests`).

### Linting

Meros supports linting via Pylint (`pylint --rcfile=PythonTests/Pylint/pylintrc PythonTests`).

### Running

`python3.6 -m PythonTests.Test`
