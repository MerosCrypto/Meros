# Integration Tests

Integration tests written in Python to test Meros's networking code and the RPC.

### Setup

These tests require Python 3.6+ and pip. To install the needed modules:

`pip3 install argon2-cffi ed25519 blspy`

### Static Typing

Meros supports static typing via both Pyright (`pyright -p PythonTests`) and MyPy (`mypy --config-file PythonTests/mypy.ini --namespace-packages PythonTests`).

### Linting

Meros supports linting via Pylint (`pylint --rcfile=PythonTests/Pylint/pylintrc PythonTests`).

### Running

`python3.6 -m PythonTests.Test`
