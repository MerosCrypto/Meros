import os
import strutils
import json

import ../../src/Wallet/Mnemonic

import ../Fuzzed

const vectorsFile: string = staticRead("Vectors" / "Mnemonic.json")
var vectors: JSONNode = parseJSON(vectorsFile)

suite "Mnemonic":
  setup:
    var
      mnemonic: Mnemonic
      reloaded: Mnemonic

  noFuzzTest "Each vector.":
    for vector in vectors["english"]:
      mnemonic = newMnemonic(vector[1].getStr())
      check:
        mnemonic.entropy.toHex().toLower() == vector[0].getStr()
        mnemonic.unlock("TREZOR").toHex().toLower() == vector[2].getStr()

  midFuzzTest "Generated Mnemonics.":
    mnemonic = newMnemonic()
    reloaded = newMnemonic(mnemonic.sentence)

    check:
      mnemonic.entropy == reloaded.entropy
      mnemonic.checksum == reloaded.checksum
      mnemonic.sentence == reloaded.sentence
      mnemonic.unlock("password") == reloaded.unlock("password")
