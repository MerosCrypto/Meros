#Mnemonic Test.

#Test lib.
import unittest2

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

    test "Each vector.":
        for vector in vectors["english"]:
            mnemonic = newMnemonic(vector[1].getStr())
            assert(mnemonic.entropy.toHex().toLower() == vector[0].getStr())
            assert(mnemonic.unlock("TREZOR").toHex().toLower() == vector[2].getStr())

    highFuzzTest "Generated Mnemonics.":
        mnemonic = newMnemonic()
        reloaded = newMnemonic(mnemonic.sentence)

        assert(mnemonic.entropy == reloaded.entropy)
        assert(mnemonic.checksum == reloaded.checksum)
        assert(mnemonic.sentence == reloaded.sentence)

        assert(mnemonic.unlock("password") == reloaded.unlock("password"))
