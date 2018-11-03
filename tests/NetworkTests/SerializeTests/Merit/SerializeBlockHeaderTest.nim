#Serialize Block Header test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS/MinerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Database/Merit/MinerWallet

#Verifications lib.
import ../../../../src/Database/Merit/Verifications

#BlockHeader object.
import ../../../../src/Database/Merit/objects/BlockHeaderObj

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeBlockHeader
import ../../../../src/Network/Serialize/Merit/ParseBlockHeader

#Random standard lib.
import random

#Set the seed to be based on the time.
randomize(int(getTime()))

#Test 20 serializations.
for nonce in 1 .. 20:
    echo "Testing BlockHeader Serialization/Parsing, iteration " & $nonce & "."

    var
        #Header.
        header: BlockHeader = BlockHeader()
        #Last Block's Hash.
        last: ArgonHash
        #Miner Wallet.
        miner: MinerWallet = newMinerWallet()
        #Verifications.
        verifs: BLSSignature
        #Miners Hash.
        miners: SHA512Hash
        #Time.
        time: uint = getTime()

    #Randomze the hashes.
    for i in 0 ..< 64:
        last.data[i] = uint8(rand(255))
        miners.data[i] = uint8(rand(255))

    #Create a Random BLS signature.
    verifs = miner.sign(last.toString())

    #Create the Header.
    header.nonce = uint(nonce)
    header.last = last
    header.verifications = verifs
    header.miners = miners
    header.time = time

    #Serialize it and parse it back.
    var headerParsed: BlockHeader = header.serialize().parseBlockHeader()

    #Test the serialized versions.
    assert(header.serialize() == headerParsed.serialize())

    #Test each field.
    assert(header.nonce == headerParsed.nonce)
    assert(header.last == headerParsed.last)
    assert(header.verifications == headerParsed.verifications)
    assert(header.miners == headerParsed.miners)
    assert(header.time == headerParsed.time)

echo "Finished the Network/Serialize/Merit/BlockHeader test."
