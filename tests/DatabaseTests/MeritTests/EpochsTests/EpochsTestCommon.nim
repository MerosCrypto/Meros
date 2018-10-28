#Epoch Tests's Common Functions.

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Miners Serialization lib.
import ../../../../src/Network/Serialize/SerializeMiners

#String utils standard lib.
import strutils

#Generates a block.
proc blankBlock*(miners: Miners): Block =
    #Create a junk Wallet/Verifications object.
    var
        wallet: Wallet = newWallet()
        verifs: Verifications = newVerificationsObj()
    verifs.calculateSig()

    result = newBlock(
        "00".repeat(64).toHash(512),
        1,
        0,
        verifs,
        wallet.publicKey,
        0,
        miners,
        wallet.sign(SHA512(miners.serialize(1)).toString())
    )
