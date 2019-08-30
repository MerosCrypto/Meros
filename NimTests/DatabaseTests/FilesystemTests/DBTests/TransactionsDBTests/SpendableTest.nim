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

#Send lib.
import ../../../../../src/Database/Transactions/Send

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
        #Wallets.
        wallets: seq[Wallet] = @[]

        #Outputs.
        outputs: seq[SendOutput]
        #Send.
        send: Send

        #Public Key -> Spendable Outputs.
        spendable: OrderedTable[string, seq[SendInput]]
        #Inputs.
        inputs: seq[SendInput]
        #Loaded Spendable.
        loaded: seq[SendInput]

    #Generate 10 wallets.
    for _ in 0 ..< 10:
        wallets.add(newWallet(""))

    #Test 100 Transactions.
    for _ in 0 .. 100:
        outputs = newSeq[SendOutput](rand(254) + 1)
        for i in 0 ..< outputs.len:
            outputs[i] = newSendOutput(
                wallets[rand(10 - 1)].publicKey,
                0
            )

            if not spendable.hasKey(outputs[i].key.toString()):
                spendable[outputs[i].key.toString()] = @[]

        send = newSend(@[newSendInput(Hash[384](), 0)], outputs)
        db.save(send)

        for o in 0 ..< outputs.len:
            spendable[outputs[o].key.toString()].add(
                newSendInput(send.hash, o)
            )

        #Spend outputs.
        for key in spendable.keys():
            if spendable[key].len == 0:
                continue

            inputs = @[]
            var i: int = 0
            while true:
                if rand(1) == 0:
                    inputs.add(spendable[key][i])
                    spendable[key].delete(i)
                else:
                    inc(i)

                if i == spendable[key].len:
                    break

            if inputs.len != 0:
                send = newSend(inputs, newSendOutput(newEdPublicKey("".pad(32)), 0))
                db.spend(send)

        #Test each spendable.
        for key in spendable.keys():
            loaded = db.loadSpendable(newEdPublicKey(key))

            assert(spendable[key].len == loaded.len)
            for i in 0 ..< spendable[key].len:
                assert(spendable[key][i].hash == loaded[i].hash)
                assert(spendable[key][i].nonce == loaded[i].nonce)

    echo "Finished the Database/Filesystem/DB/TransactionsDB/Spendable Test."
