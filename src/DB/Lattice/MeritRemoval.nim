#Number lib.
import ../../lib/BN

#SHA512 lib.
import ../../lib/SHA512

#Errors lib.
import ../../lib/Errors

#Wallet lib.
import ../../Wallet/Wallet

#Lattice libs.
import Node
import Verification

type MeritRemoval* = ref object of Node
    first: Verification
    second: Verification

proc newMeritRemoval*(nonce: BN, first: Verification, second: Verification): MeritRemoval {.raises: [ResultError].} =
    result = MeritRemoval(
        first: first,
        second: second
    )

    if not result.setHash(SHA512(first.getHash() & second.getHash())):
        raise newException(ResultError, "Couldn't set the Merit Removal hash.")

proc sign*(wallet: Wallet, removal: MeritRemoval): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = removal.setSignature(wallet.sign(removal.getHash()))
