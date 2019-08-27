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

#Compare Merit lib.
import ../../../DatabaseTests/MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Hash.
        hash: Hash[384]
        #Records.
        records: seq[MeritHolderRecord]
        #Reloaded Records.
        reloaded: seq[MeritHolderRecord]

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the records.
        records = @[]
        for _ in 0 ..< s:
            for b in 0 ..< 48:
                hash.data[b] = uint8(rand(255))

            #Add the record.
            records.add(
                newMeritHolderRecord(
                    newMinerWallet().publicKey,
                    rand(high(int32)),
                    hash
                )
            )

        #Serialize it and parse it back.
        reloaded = records.serialize().parseRecords()

        #Test the serialized versions.
        assert(records.serialize() == reloaded.serialize())

        #Compare the Records.
        compare(records, reloaded)

    echo "Finished the Network/Serialize/Merit/Records Test."
