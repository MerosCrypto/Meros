#TransactionsDB Spendable Test.
#Tests saving UTXOs, checking which UYTXOs an account can spend, and deleting UTXOs.

#Util lib.
import ../../../../../src/lib/Util

#Hash lib.
import ../../../../../src/lib/Hash

#Wallet lib.
import ../../../../../src/Wallet/Wallet

#TransactionDB lib.
import ../../../../../src/Database/Filesystem/DB/TransactionsDB

#Input/Output objects.
import ../../../../../src/Database/Transactions/objects/TransactionObj

#Test Database lib.
import ../../../TestDatabase

#Algorithm standard lib.
import algorithm

#Tables lib.
import tables

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #DB.
        db = newTestDatabase()
        #Hash.
        hash: Hash[384]
        #UTXOs.
        utxos: seq[SendOutput]
        #Wallets.
        wallets: seq[Wallet] = @[]
        #Public Key -> Spendable Outputs.
        spendable: Table[string, seq[SendInput]]
        #Loaded Spendable UTXOs.
        loaded: seq[SendInput]

    proc sortInputs(
        x: SendInput,
        y: SendInput
    ): int =
        if x.hash > y.hash:
            result = 1
        elif x.hash == y.hash:
            if x.nonce > y.nonce:
                result = 1
            elif x.nonce == y.nonce:
                result = 0
            else:
                result = -1
        else:
            result = -1

    #Generate 10 wallets.
    for _ in 0 ..< 10:
        wallets.add(newWallet(""))

    #Test 100 'Transaction's.
    for _ in 0 .. 100:
        #Generate outputs.
        for i in 0 ..< hash.data.len:
            hash.data[i] = uint8(rand(255))

        utxos = newSeq[SendOutput](rand(254) + 1)
        for i in 0 ..< utxos.len:
            utxos[i] = newSendOutput(
                wallets[rand(10 - 1)].publicKey,
                0
            )

            if not spendable.hasKey(utxos[i].key.toString()):
                spendable[utxos[i].key.toString()] = @[]

            spendable[utxos[i].key.toString()].add(
                newSendInput(hash, i)
            )

        db.save(hash, utxos)

        #Spend outputs.
        for key in spendable.keys():
            if spendable[key].len == 0:
                continue

            var i: int = 0
            while true:
                if rand(1) == 0:
                    db.deleteUTXO(spendable[key][i].hash, spendable[key][i].nonce)
                    spendable[key].del(i)
                else:
                    inc(i)

                if i == spendable[key].len:
                    break

        #Test outputs.
        for key in spendable.keys():
            spendable[key].sort(sortInputs, SortOrder.Descending)

            loaded = db.loadSpendable(newEdPublicKey(key))
            loaded.sort(sortInputs, SortOrder.Descending)

            assert(spendable[key].len == loaded.len)
            for i in 0 ..< spendable[key].len:
                assert(spendable[key][i].hash == loaded[i].hash)
                assert(spendable[key][i].nonce == loaded[i].nonce)

    echo "Finished the Database/Filesystem/DB/TransactionsDB/Spendable Test."
