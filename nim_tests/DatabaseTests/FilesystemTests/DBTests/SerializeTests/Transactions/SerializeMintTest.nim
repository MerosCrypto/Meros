#Serialize Mint Test.

#Util lib.
import ../../../../../../src/lib/Util

#Hash lib.
import ../../../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../../../src/Wallet/MinerWallet

#Mint lib.
import ../../../../../../src/Database/Transactions/Mint

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/SerializeMint
import ../../../../../../src/Database/Filesystem/DB/Serialize/Transactions/ParseMint

#Compare Transactions lib.
import ../../../../TransactionsTests/CompareTransactions

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Mint.
        mint: Mint
        #Reloaded Mint.
        reloaded: Mint

    #Test 255 serializations.
    for s in 0 .. 255:
        #Create the Mint.
        mint = newMint(
            uint32(rand(high(int32))),
            newMinerWallet().publicKey,
            uint64(rand(high(int32)))
        )

        #Serialize it and parse it back.
        reloaded = mint.serialize().parseMint()

        #Compare the Mints.
        compare(mint, reloaded)

        #Test the serialized versions.
        assert(mint.serialize() == reloaded.serialize())

    echo "Finished the Database/Filesystem/DB/Serialize/Transactions/Mint Test."
