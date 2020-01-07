# Unit Tests

### Convention

If the following conventions are followed, everything should _just work_.

- The file name MUST follow the pattern `*Test.nim`.
- It MUST use [`unittest2`](https://github.com/stefantalpalaru/nim-unittest2) framework and thereby format.

### Running Tests

##### All unit tests

```shell
nimble unit
```

###### A specific set of unit tests

```shell
nimble unit "some test" "some other test"
```

###### A specific set of suites

```shell
nimble unit "some suite::" "some other suite::"
```

### Configuration

- [`ci.cfg`][ci-config] - Configuration used specifically for CI. Used by `nimble ci`.
- [config.nims][config-nims] - All required configuration for running unit tests.

[ci-config]: ci.cfg
[config-nims]: config.nims
