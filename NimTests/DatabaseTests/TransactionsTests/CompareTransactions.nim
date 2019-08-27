#Hash lib.
import ../../../src/lib/Hash

#Wallet libs.
import ../../../src/Wallet/Wallet
import ../../../src/Wallet/MinerWallet

#Various Transaction libs.
import ../../../src/Database/Transactions/Transactions

#Tables lib.
import tables

#Compare two MintOutputs to make sure they have the same value.
proc compare*(
    so1: MintOutput,
    so2: MintOutput
) =
    assert(so1.amount == so2.amount)
    assert(so1.key == so2.key)

#Compare two SendOutputs to make sure they have the same value.
proc compare*(
    so1: SendOutput,
    so2: SendOutput
) =
    assert(so1.amount == so2.amount)
    assert(so1.key == so2.key)

#Compare two Transactions to make sure they have the same value.
proc compare*(
    tx1: Transaction,
    tx2: Transaction
) =
    #Test the Transaction fields.
    assert(tx1.inputs.len == tx2.inputs.len)
    for i in 0 ..< tx1.inputs.len:
        assert(tx1.inputs[i].hash == tx2.inputs[i].hash)
    assert(tx1.outputs.len == tx2.outputs.len)
    assert(tx1.hash == tx2.hash)
    assert(tx1.verified == tx2.verified)

    #Test the sub-type fields.
    case tx1:
        of Mint as mint:
            if not (tx2 of Mint):
                assert(false)
            for o in 0 ..< tx1.outputs.len:
                compare(cast[MintOutput](tx1.outputs[o]), cast[MintOutput](tx2.outputs[o]))
            assert(mint.nonce == cast[Mint](tx2).nonce)

        of Claim as claim:
            if not (tx2 of Claim):
                assert(false)
            for o in 0 ..< tx1.outputs.len:
                compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))
            assert(claim.signature == cast[Claim](tx2).signature)

        of Send as send:
            if not (tx2 of Send):
                assert(false)
            for i in 0 ..< tx1.inputs.len:
                assert(cast[SendInput](tx1.inputs[i]).nonce == cast[SendInput](tx2.inputs[i]).nonce)
            for o in 0 ..< tx1.outputs.len:
                compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))
            assert(send.signature == cast[Send](tx2).signature)
            assert(send.proof == cast[Send](tx2).proof)
            assert(send.argon == cast[Send](tx2).argon)

        of Data as data:
            if not (tx2 of Data):
                assert(false)
            assert(data.data == cast[Data](tx2).data)
            assert(data.signature == cast[Data](tx2).signature)
            assert(data.proof == cast[Data](tx2).proof)
            assert(data.argon == cast[Data](tx2).argon)

#Compare two Transactions DAGs to make sure they have the same value.
proc compare*(
    txs1: Transactions,
    txs2: Transactions
) =
    #Test the difficulties.
    assert(txs1.difficulties.send == txs2.difficulties.send)
    assert(txs1.difficulties.data == txs2.difficulties.data)

    #Test the mint nonce.
    assert(txs1.mintNonce == txs2.mintNonce)

    #Test the transactions.
    assert(txs1.transactions.len == txs2.transactions.len)
    for hash in txs1.transactions.keys():
        compare(txs1.transactions[hash], txs2.transactions[hash])

    #Test the weights.
    assert(txs1.weights.len == txs2.weights.len)
    for hash in txs1.weights.keys():
        assert(txs1.weights[hash] == txs2.weights[hash])

    #Test the spent tables.
    for input in txs1.spent.keys():
        #We only create 1 potential Send.
        #As Datas are sequential, we do create multiple potential Datas.
        #Without a sorting algorithm when reloading, we can't guarantee consistency.
        #As long as the Data is marked as spent by SOMETHING, we don't risk creating new Verifications.
        if not (txs1[input.substr(0, 47).toHash(384)] of Data):
            assert(txs1.spent[input] == txs2.spent[input])

    #Beyond that, if a Data doesn't get verified, and a later Data is added:
    #TXS1 will think only the original Data was there.
    #TXS2 will only reload the newer Data.
    #TXS2 will therefore have a spent entry TXS1 doesn't have, and the lengths will be different.
    #We need to replicate the above loop in reverse still ignoring Datas.
    #This will not be a problem in mainnet Meros thanks to defaulting.
    for input in txs2.spent.keys():
        if not (txs2[input.substr(0, 47).toHash(384)] of Data):
            assert(txs1.spent[input] == txs2.spent[input])
