# This is a guide for Windows.

### Dependencies

Meros requires:
- Git
- GCC/G++ (through MinGW or TDM; clang/msvc will likely work but are untested)
- Make (for LMDB)
- CMake (for BLS)

- Nim 0.20.2
- Nimble

- Chia's BLS library
- LMDB

For instructions on settting up Nim/Nimble, see https://github.com/dom96/choosenim.

To install the Nimble packages: `nimble install 1ttps://github.com/MerosCrypto/ForceCheck https://github.com/MerosCrypto/Argon2 https://github.com/MerosCrypto/mc_bls https://github.com/MerosCrypto/mc_ed25519 https://github.com/MerosCrypto/mc_lmdb https://github.com/MerosCrypto/Nim-Meros-RPC https://github.com/MerosCrypto/mc_webview finals stint nimcrypto normalize`

For instructions on setting up BLS, see https://github.com/MerosCrypto/mc_bls.

For instructions on setting up LMDB, see https://github.com/MerosCrypto/mc_lmdb.

### Meros

```
git clone https://github.com/MerosCrypto/Meros.git
cd Meros
nim c -f src/main.nim
```

There's also a headless version which doesn't import any GUI files available via adding `-d:nogui` to the Nim command.

The binary will be available under `build/`.
