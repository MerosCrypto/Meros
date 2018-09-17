#Serialize Data Test.

#Numerical libs.
import BN
import ../../../src/lib/Base

#Hash lib.
import ../../../src/lib/Hash

#Wallet lib.
import ../../../src/Wallet/Wallet

#Node object and the Data lib.
import ../../../src/Database/Lattice/objects/NodeObj
import ../../../src/Database/Lattice/Data

#Serialize lib.
import ../../../src/Network/Serialize/SerializeData
import ../../../src/Network/Serialize/ParseData

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#Test data.
var tests: seq[string] = @[
    "",
    "123",
    "abc",
    "abcdefghijklmnopqrstuvwxyz",
    "test",
    "test1",
    "test2",
    "This is a longer test.",
    "Now we have special character.\r\n",
    "Write the tests they said.",
    "Make up phrases they said.",
    "Well here are the phrases.",
    "I make the phrases, I pick them.",
    "This is 1024 characters long.   ".repeat(32),
    "This is the 15th tests because I wanted a nice number."
]

#Test 15 serializations.
for i in 1 .. 15:
    echo "Testing Data Serialization/Parsing, iteration " & $i & "."

    var
        #Wallet.
        wallet: Wallet = newWallet()
        #Data.
        data: Data = newData(
            tests[i - 1],
            newBN()
        )
    #Mine the Data.
    data.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
    #Sign it.
    wallet.sign(data)

    #Serialize it and parse it back.
    var dataParsed: Data = data.serialize().parseData()

    #Test the serialized versions.
    assert(data.serialize() == dataParsed.serialize())

    #Test the Node properties.
    assert(data.descendant == dataParsed.descendant)
    assert(data.sender == dataParsed.sender)
    assert(data.nonce == dataParsed.nonce)
    assert(data.hash == dataParsed.hash)
    assert(data.signature == dataParsed.signature)

    #Test the Data properties.
    assert(data.data == dataParsed.data)
    assert(data.sha512 == dataParsed.sha512)
    assert(data.proof == dataParsed.proof)

echo "Finished the Network/Serialize/Data test."
