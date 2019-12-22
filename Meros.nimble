import os

version     = "0.0.1"
author      = "Luke Parker"
description = "Meros Cryptocurrency"
license     = "MIT"

binDir = "build"
bin = @["Meros"]
srcDir = "src"
skipExt = @["nim"]

# Dependencies
requires "nim >= 1.0.4"
requires "https://github.com/MerosCrypto/ForceCheck"
requires "https://github.com/MerosCrypto/Argon2"
requires "https://github.com/MerosCrypto/mc_bls"
requires "https://github.com/MerosCrypto/mc_ed25519"
requires "https://github.com/MerosCrypto/mc_minisketch"
requires "https://github.com/MerosCrypto/mc_lmdb"
requires "https://github.com/MerosCrypto/Nim-Meros-RPC"
requires "https://github.com/MerosCrypto/mc_webview"
requires "finals"
requires "stint"
requires "nimcrypto"
requires "normalize"

# Solely used to display as part of `nimble tasks`
task install, "Install Meros":
    setCommand "nop"

# Solely used to display as part of `nimble tasks`
task build, "Build Meros":
    setCommand "nop"

task clean, "Clean workspace":
    rmDir projectDir() / "build"