#Serialize Records Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeRecords
import ../../../../src/Network/Serialize/Merit/ParseRecords

#Random standard lib.
import random

#Algorithm standard lib; used to randomize the Records/Miners order.
import algorithm

#Seed Random via the time.
randomize(int(getTime()))

for i in 1 .. 20:
    echo "Testing Records Serialization/Parsing, iteration " & $i & "."

    var
        #seq of MeritHolderRecord.
        records: seq[MeritHolderRecord] = newSeq[MeritHolderRecord](rand(99) + 1)
        key: string
        nonce: int
        merkle: string

    #Fill up the MeritHolderRecords.
    for r in 0 ..< records.len:
        #Reset the key and merkle.
        key = newString(48)
        merkle = newString(48)

        #Randomize the key.
        for b in 0 ..< key.len:
            key[b] = char(rand(255))

        #Randomize the nonce.
        nonce = rand(100000)

        #Randomize the merkle.
        for b in 0 ..< merkle.len:
            merkle[b] = char(rand(255))

        records[r] = newMeritHolderRecord(
            newBLSPrivateKeyFromSeed(key).getPublicKey(),
            nonce,
            merkle.toHash(384)
        )

    #Serialize it and parse it back.
    var recordsParsed: seq[MeritHolderRecord] = records.serialize().parseRecords()

    #Test the serialized versions.
    assert(records.serialize() == recordsParsed.serialize())

    #Test the Records.
    for r in 0 ..< records.len:
        assert(records[r].key == recordsParsed[r].key)
        assert(records[r].nonce == recordsParsed[r].nonce)
        assert(records[r].merkle == recordsParsed[r].merkle)

echo "Finished the Network/Serialize/Merit/Records Test."
