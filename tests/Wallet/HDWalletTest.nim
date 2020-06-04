import os
import math
import strutils
import json

import ../../src/lib/[Util, Hash]

import ../../src/Wallet/HDWallet

import ../Fuzzed

const vectorsFile: string = staticRead("Vectors" / "HDWallet.json")
var vectors: JSONNode = parseJSON(vectorsFile)

suite "HDWallet":
  setup:
    var
      wallet: HDWallet

      path: seq[uint32]
      child: string
      i: uint32

  noFuzzTest "Each vector.":
    for vector in vectors:
      #Extract the path.
      path = @[]
      if vector["path"].getStr().len != 0:
        for childArg in vector["path"].getStr().split('/'):
          child = childArg
          i = 0
          if child[^1] == '\'':
            i = uint32(2^31)
            child = child.substr(0, child.len - 2)
          i += uint32(parseUInt(child))
          path.add(i)

      #Make sure invalid secrets/paths are invalid.
      if vector["node"].kind == JNull:
        expect ValueError:
          wallet = newHDWallet(vector["secret"].getStr()).derive(path)
        continue

      #If this wallet is valid, load and derive it.
      wallet = newHDWallet(vector["secret"].getStr()).derive(path)

      #Compare the Wallet with the vector.
      check:
        $wallet.privateKey == (vector["node"]["kLP"].getStr() & vector["node"]["kRP"].getStr()).toUpper()
        $wallet.publicKey == vector["node"]["AP"].getStr().toUpper()
        $wallet.chainCode == vector["node"]["cP"].getStr().toUpper()
