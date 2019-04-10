#Serialize Miners Test.

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeMiners
import ../../../../src/Network/Serialize/Merit/ParseMiners

#Random/Algorithm standard libs, used to randomize the testing data.
import random
import algorithm

#Seed Random via the time.
randomize(int(getTime()))

#Test 20 serializations.
for i in 1 .. 20:
    var
        #Wallets.
        wallets: seq[MinerWallet] = @[]
        #Miners.
        miners: Miners = newMinersObj(@[])
        #Quantity.
        quantity: int = rand(99) + 1 #Returns between 1 to 100.
        #Amount temp variable.
        amount: int
        #Remaining amount.
        remaining: int = 100

    #Test the lowest quantity.
    if i == 1:
        quantity = 1
    #Test the highest quantity.
    elif i == 20:
        quantity = 100

    echo "Testing Miners Serialization/Parsing, iteration " & $i & ", with " & $quantity & " miners."

    for i in 0 ..< quantity:
        #Generate a Wallet for them.
        wallets.add(newMinerWallet())

        #Set the amount to pay the miner.
        amount = rand(remaining - 1) + 1
        #Make sure everyone gets at least 1 and we don't go over 100.
        if (remaining - amount) < (quantity - i):
            amount = 1
        #But if this is the last account...
        if i == quantity - 1:
            amount = remaining

        #Add the Miner.
        miners.add(newMinerObj(
            wallets[i].publicKey,
            amount
        ))

        #Subtract the amount from remaining.
        remaining -= amount

    #Randomly order the miners.
    miners.miners.sort(
        proc (x: Miner, y: Miner): int =
            rand(1000)
    )

    #Serialize it and parse it back.
    var minersParsed: Miners = miners.serialize().parseMiners()

    #Test the serialized versions.
    assert(miners.serialize() == minersParsed.serialize())

    #Test the length.
    assert(miners.miners.len == minersParsed.miners.len)

    #Test each miner for equality.
    for i in 0 ..< miners.miners.len:
        assert(miners.miners[i].miner == minersParsed.miners[i].miner)
        assert(miners.miners[i].amount == minersParsed.miners[i].amount)

echo "Finished the Network/Serialize/Merit/Miners Test."
