#Hash lib.
import ../../../src/lib/Hash

#Wallet libs.
import ../../../src/Wallet/Wallet
import ../../../src/Wallet/MinerWallet

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Transaction object.
import ../../../src/Database/Transactions/objects/TransactionObj

#Various Transaction libs.
import ../../../src/Database/Transactions/Mint
import ../../../src/Database/Transactions/Claim
import ../../../src/Database/Transactions/Send

#Tables lib.
import tables

#Compare two Entries to make sure they have the same value.
proc compare*(
    e1: Transaction,
    e2: Transaction
) =
    #Test the Transaction fields.
    assert(e1.descendant == e2.descendant)
    assert(e1.inputs.len == e2.inputs.len)
    for i in 0 ..< e1.inputs.len:
        assert(e1.inputs[i].hash == e2.inputs[i].hash)
    assert(e1.outputs.len == e2.outputs.len)
    for o in 0 ..< e1.outputs.len:
        assert(e1.outputs[o].amount == e2.outputs[o].amount)
    assert(e1.hash == e2.hash)
    assert(e1.verified == e2.verified)

    #Test the sub-type fields.
    case e1.descendant:
        of TransactionType.Mint:
            for o in 0 ..< e1.outputs.len:
                assert(cast[MintOutput](e1.outputs[o]).key == cast[MintOutput](e2.outputs[o]).key)
            assert(cast[Mint](e1).nonce == cast[Mint](e2).nonce)

        of TransactionType.Claim:
            assert(e1.outputs[0].amount == 0)
            for o in 0 ..< e1.outputs.len:
                assert(cast[SendOutput](e1.outputs[o]).key == cast[SendOutput](e2.outputs[o]).key)
            assert(cast[Claim](e1).signature == cast[Claim](e2).signature)

        of TransactionType.Send:
            for i in 0 ..< e1.inputs.len:
                assert(cast[SendInput](e1.inputs[i]).nonce == cast[SendInput](e2.inputs[i]).nonce)
            for o in 0 ..< e1.outputs.len:
                assert(cast[SendOutput](e1.outputs[o]).key == cast[SendOutput](e2.outputs[o]).key)
            assert(cast[Send](e1).signature == cast[Send](e2).signature)
            assert(cast[Send](e1).proof == cast[Send](e2).proof)
            assert(cast[Send](e1).argon == cast[Send](e2).argon)
