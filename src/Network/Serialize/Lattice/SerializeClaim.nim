#Util lib.
import ../../../lib/Util

#Base lib.
import ../../../lib/Base

#BLS lib.
import ../../../lib/BLS

#Address library.
import ../../../Wallet/Address

#Entry and Claim objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/ClaimObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Claim.
proc serialize*(claim: Claim): string {.raises: [ValueError].} =
    result =
        claim.nonce.toBinary().pad(INT_LEN) &
        claim.mintNonce.toBinary().pad(INT_LEN) &
        claim.bls.toString()

    if claim.signature.len != 0:
        result =
            Address.toPublicKey(claim.sender) &
            result &
            claim.signature
