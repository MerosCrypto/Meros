import os

version     = "0.6.0"
author      = "Luke Parker"
description = "Meros Cryptocurrency"
license     = "MIT"

binDir = "build"
bin = @["Meros"]
srcDir = "src"
skipExt = @["nim"]

# Dependencies
requires "nim >= 1.0.4"
requires "https://github.com/MerosCrypto/Argon2"
requires "https://github.com/MerosCrypto/mc_bls"
requires "https://github.com/MerosCrypto/mc_ed25519"
requires "https://github.com/MerosCrypto/mc_minisketch"
requires "https://github.com/MerosCrypto/mc_lmdb"
requires "https://github.com/MerosCrypto/Nim-Meros-RPC"
requires "https://github.com/MerosCrypto/mc_webview"
requires "https://github.com/kayabaNerve/ForceCheck >= 1.3.2"
requires "stint"
requires "nimcrypto"
requires "normalize"

task clean, "Clean all build files.":
    rmDir projectDir() / "build"

#Solely used to display as part of `nimble tasks`.
task build, "Build Meros.":
    setCommand "nop"

task install, "Install Meros.":
    setCommand "nop"
