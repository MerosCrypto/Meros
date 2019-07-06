#HDWallet Test.

#Util lib.
import ../../src/lib/Util

#Hash lib.
import ../../src/lib/Hash

#HDWallet lib.
import ../../src/Wallet/HDWallet

#OS standard lib.
import os

#Math standard lib.
import math

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Vectors File.
const vectorsFile: string = staticRead("Vectors" / "HDWallet.json")

proc test*() =
    var
        #HDWallets.
        wallet: HDWallet

        #Test vectors.
        vectors: JSONNode = parseJSON(vectorsFile)

        #Path.
        path: seq[uint32]
        #Child on the path.
        child: string
        #Numeric value of a child.
        i: uint32

        #Loop variable signifying if newHDWallet raised.
        raised: bool

    #Test each vector.
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

        #If this secret/path is invalid...
        if vector["node"].kind == JNull:
            #Make sure it throws.
            raised = false
            try:
                wallet = newHDWallet(vector["secret"].getStr()).derive(path)
            except:
                raised = true
            assert(raised)
            continue

        #If this wallet is valid, load and derive it.
        wallet = newHDWallet(vector["secret"].getStr()).derive(path)

        #Compare the Wallet with the vector.
        assert($wallet.privateKey == (vector["node"]["kLP"].getStr() & vector["node"]["kRP"].getStr()).toUpper())
        assert($wallet.publicKey == vector["node"]["AP"].getStr().toUpper())
        assert($wallet.chainCode == vector["node"]["cP"].getStr().toUpper())

    echo "Finished the Wallet/HDWallet Test."
