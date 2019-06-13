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
    assert(tx1.descendant == tx2.descendant)
    assert(tx1.inputs.len == tx2.inputs.len)
    for i in 0 ..< tx1.inputs.len:
        assert(tx1.inputs[i].hash == tx2.inputs[i].hash)
    assert(tx1.outputs.len == tx2.outputs.len)
    assert(tx1.hash == tx2.hash)
    assert(tx1.verified == tx2.verified)

    #Test the sub-type fields.
    case tx1.descendant:
        of TransactionType.Mint:
            for o in 0 ..< tx1.outputs.len:
                compare(cast[MintOutput](tx1.outputs[o]), cast[MintOutput](tx2.outputs[o]))
                assert(cast[Mint](tx1).nonce == cast[Mint](tx2).nonce)

        of TransactionType.Claim:
            assert(tx1.outputs[0].amount == 0)
            for o in 0 ..< tx1.outputs.len:
                compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))
            assert(cast[Claim](tx1).signature == cast[Claim](tx2).signature)

        of TransactionType.Send:
            for i in 0 ..< tx1.inputs.len:
                assert(cast[SendInput](tx1.inputs[i]).nonce == cast[SendInput](tx2.inputs[i]).nonce)
            for o in 0 ..< tx1.outputs.len:
                compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))
            assert(cast[Send](tx1).signature == cast[Send](tx2).signature)
            assert(cast[Send](tx1).proof == cast[Send](tx2).proof)
            assert(cast[Send](tx1).argon == cast[Send](tx2).argon)
