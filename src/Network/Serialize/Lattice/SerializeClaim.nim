#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Address lib.
import ../../../Wallet/Address

#Entry and Claim objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/ClaimObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Claim.
func serialize*(
    claim: Claim
): string {.forceCheck: [
    AddressError
].} =
    result =
        claim.nonce.toBinary().pad(INT_LEN) &
        claim.mintNonce.toBinary().pad(INT_LEN) &
        claim.bls.toString()

    if claim.signature.len != 0:
        var sender: string
        try:
            sender = Address.toPublicKey(claim.sender)
        except AddressError as e:
            fcRaise e

        result =
            sender &
            result &
            claim.signature
    else:
        result = "claim" & result
