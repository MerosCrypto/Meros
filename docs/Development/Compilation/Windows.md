# This is a guide for Windows.

### Dependencies

Meros requires Git, GCC/G++ (through MinGW or TDM; clang/msvc will likely work but are untested), Nim 0.19.4, Nimble, GMP, Chia's BLS library, and LibSodium.

- For how to install Nim/Nimble, see https://nim-lang.org/install_windows.html.
- For GMP, go to https://github.com/Legrandin/mpir-windows-builds. Download the MPIR DLL for your platform, and put it in your `/build` directory as `libgmp.dll`.
- For BLS, see https://github.com/MerosCrypto/mc_bls.
- For LibSodium, download https://download.libsodium.org/libsodium/releases/libsodium-1.0.16-mingw.tar.gz. Extract the files and open the folder for your arch. Place `bin/libsodium-23.dll` in your `/build` directory. Place `lib/libsodium.a` in your compiler's static library folder.

Now, install the Nimble packages.

```
nimble install BN mc_events https://github.com/MerosCrypto/Argon2 https://github.com/MerosCrypto/Nim-Meros-RPC https://github.com/MerosCrypto/mc_bls https://github.com/MerosCrypto/mc_webview
nimble install finals nimcrypto rocksdb
```

### Meros

```
git clone https://github.com/MerosCrypto/Meros.git
cd Meros
nim c src/main.nim
```

If you want to build an optimized version, put `-d:release` after `c`. There's also a headless version which doesn't import any GUI files available via `-d:nogui`.

The binary will be available under `build/`.
