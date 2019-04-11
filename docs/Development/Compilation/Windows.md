# This is a guide for Windows.

### Dependencies

Meros requires:
- Git
- GCC/G++ (through MinGW or TDM; clang/msvc will likely work but are untested)
- Make (for LMDB)
- CMake (for BLS)

- Nim devel
- Nimble

- GMP
- Chia's BLS library
- LibSodium
- LMDB

- For instructions on settting up Nim/Nimble, see https://github.com/dom96/choosenim.
- To install the Nimble packages: `nimble install BN https://github.com/MerosCrypto/ForceCheck https://github.com/MerosCrypto/Argon2 https://github.com/MerosCrypto/mc_bls https://github.com/MerosCrypto/mc_ed25519 https://github.com/MerosCrypto/mc_lmdb https://github.com/MerosCrypto/Nim-Meros-RPC https://github.com/MerosCrypto/mc_webview finals nimcrypto`
- For GMP, go to https://github.com/Legrandin/mpir-windows-builds. Download the MPIR DLL for your platform, and put it in your `/build` directory as `libgmp.dll`.
- For instructions on setting up BLS, see https://github.com/MerosCrypto/mc_bls.
- For instructions on setting up LibSodium, see https://github.com/MerosCrypto/mc_ed25519.
- For instructions on setting up LMDB, see https://github.com/MerosCrypto/mc_lmdb.

### Meros

```
git clone https://github.com/MerosCrypto/Meros.git
cd Meros
nim c src/main.nim
```

If you want to build an optimized version, put `-d:release` after `c`. There's also a headless version which doesn't import any GUI files available via `-d:nogui`.

The binary will be available under `build/`.
