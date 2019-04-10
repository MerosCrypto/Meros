#Serialize Block Header Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#BlockHeader object.
import ../../../../src/Database/Merit/objects/BlockHeaderObj

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeBlockHeader
import ../../../../src/Network/Serialize/Merit/ParseBlockHeader

#Random standard lib.
import random

#Seed Random via the time.
randomize(int(getTime()))

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing BlockHeader Serialization/Parsing, iteration " & $i & "."

    var
        #Header.
        header: BlockHeader = BlockHeader()
        #Nonce.
        nonce: uint = uint(rand(65000))
        #Last Block's Hash.
        last: ArgonHash
        #Miner Wallet.
        miner: MinerWallet = newMinerWallet()
        #Aggregate Signature of the Verifications.
        agg: BLSSignature
        #Miners Hash.
        miners: Blake384Hash
        #Time.
        time: int64 = getTime()
        #Proof.
        proof: int = rand(500000)

    #Randomze the hashes.
    for b in 0 ..< 48:
        last.data[b] = uint8(rand(255))
        miners.data[b] = uint8(rand(255))

    #Create a Random BLS signature.
    agg = miner.sign(last.toString())

    #Create the Header.
    header.nonce = uint(nonce)
    header.last = last
    header.aggregate = agg
    header.miners = miners
    header.time = time
    header.proof = proof

    #Serialize it and parse it back.
    var headerParsed: BlockHeader = header.serialize().parseBlockHeader()

    #Test the serialized versions.
    assert(header.serialize() == headerParsed.serialize())

    #Test each field.
    assert(header.nonce == headerParsed.nonce)
    assert(header.last == headerParsed.last)
    assert(header.aggregate == headerParsed.aggregate)
    assert(header.miners == headerParsed.miners)
    assert(header.time == headerParsed.time)
    assert(header.proof == headerParsed.proof)

echo "Finished the Network/Serialize/Merit/BlockHeader Test."
