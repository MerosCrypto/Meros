#HDWallet Test.

#Util lib.
import ../../src/lib/Util

#Hash lib.
import ../../src/lib/Hash

#HDWallet libs.
import ../../src/Wallet/HDWallet

#OS standard lib.
import os

#Math standard lib.
import math

#String utils standard lib.
import strutils

#JSON standard lib.
import json

var
    #HDWallets.
    wallet: HDWallet
    reloaded: HDWallet

    #Test vectors.
    vectors: JSONNode = parseJSON(readFile("." / "nim_tests" / "WalletTests" / "Vectors" / "HDWalletVectors.json"))

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

    #Check the intiated field and index.
    assert(wallet.initiated)
    if path.len == 0:
        assert(wallet.i == 0)
    else:
        assert(wallet.i == path[^1])

    #Compare the Wallet with the vector.
    assert($wallet.privateKey == (vector["node"]["kLP"].getStr() & vector["node"]["kRP"].getStr()).toUpper())
    assert($wallet.publicKey == vector["node"]["AP"].getStr().toUpper())
    assert($wallet.chainCode == vector["node"]["cP"].getStr().toUpper())

    #Test loading wallets with a chain code.
    wallet = newHDWallet(vector["secret"].getStr())
    reloaded = newHDWallet(vector["secret"].getStr(), wallet.chainCode)

    #Compare the Wallets.
    assert(wallet.i == reloaded.i)
    assert(reloaded.initiated)
    assert(wallet.privateKey.toString() == reloaded.privateKey.toString())
    assert(wallet.publicKey.toString() == reloaded.publicKey.toString())
    assert(wallet.chainCode == reloaded.chainCode)

#Generate 100 random HDwallets.
for _ in 0 .. 100:
    wallet = newHDWallet()
    assert(wallet.initiated)

echo "Finished the Wallet/HDWallet Test."
