#Mnemonic Test.

#Test lib.
import unittest

#Fuzzing lib.
import ../Fuzzed

#Mnemonic lib.
import ../../src/Wallet/Mnemonic

#OS standard lib.
import os

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Vectors File.
const vectorsFile: string = staticRead("Vectors" / "Mnemonic.json")

suite "Mnemonic":
    setup:
        var
            #Mnemonic objects.
            mnemonic: Mnemonic
            reloaded: Mnemonic

            #Test vectors.
            vectors: JSONNode = parseJSON(vectorsFile)

    noFuzzTest "Each vector.":
        for vector in vectors["english"]:
            mnemonic = newMnemonic(vector[1].getStr())
            check(mnemonic.entropy.toHex().toLower() == vector[0].getStr())
            check(mnemonic.unlock("TREZOR").toHex().toLower() == vector[2].getStr())

    midFuzzTest "Generated Mnemonics.":
        mnemonic = newMnemonic()
        reloaded = newMnemonic(mnemonic.sentence)

        check(mnemonic.entropy == reloaded.entropy)
        check(mnemonic.checksum == reloaded.checksum)
        check(mnemonic.sentence == reloaded.sentence)

        check(mnemonic.unlock("password") == reloaded.unlock("password"))
