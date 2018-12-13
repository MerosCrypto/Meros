#Serialize Data Test.

#Base lib.
import ../../../../src/lib/Base

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object and the Data lib.
import ../../../../src/Database/Lattice/objects/EntryObj
import ../../../../src/Database/Lattice/Data

#Serialize lib.
import ../../../../src/Network/Serialize/Lattice/SerializeData
import ../../../../src/Network/Serialize/Lattice/ParseData

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
    "-----",
    "#^&^%^&*",
    "Phrase.",
    "Another phrase.",
    "Yet another phrase.",
    "This is 32 characters long.     ",
    "This is 256 characters long.    ".repeat(8),
    "This is the 20th test because I wanted a nice number."
]

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Data Serialization/Parsing, iteration " & $i & "."

    var
        #Wallet.
        wallet: Wallet = newWallet()
        #Data.
        data: Data = newData(
            tests[i - 1],
            0
        )

    #Mine the Data.
    data.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
    #Sign it.
    assert(wallet.sign(data))

    #Serialize it and parse it back.
    var dataParsed: Data = data.serialize().parseData()

    #Test the serialized versions.
    assert(data.serialize() == dataParsed.serialize())

    #Test the Entry properties.
    assert(data.descendant == dataParsed.descendant)
    assert(data.sender == dataParsed.sender)
    assert(data.nonce == dataParsed.nonce)
    assert(data.hash == dataParsed.hash)
    assert(data.signature == dataParsed.signature)

    #Test the Data properties.
    assert(data.data == dataParsed.data)
    assert(data.sha512 == dataParsed.sha512)
    assert(data.proof == dataParsed.proof)

echo "Finished the Network/Serialize/Lattice/Data test."
