discard """
    This file parses Mints so we can load them from the Database.
    Originally, parsing a Mint was a stupid idea because:
        - We never did it.
        - We shouldn't have down it back then.
    That said, now we have to, and should, for the DB.

    Back in the day, I wrote this note explaining things in the name of safety.
    Now, even though it's semi irrelevant, I find it hard to delete it.
    t's fun. It's part of Meros. It could still apply. Therefore, it shall remain.
    Enjoy.
    --Luke Parker
"""

discard """
    Hello,

    I see you are trying to parse a Mint. Why? Let me guess!
        - Because we currently don't.
        - You want to know the format.
    Am I right? Let me explain why we don't, as to make clear how this not an oversight.

    We don't parse Mints because Mints should always be created by the local Node.
    By parsing a Block, you parse all the mint needed for a Mint, and should create one yourself.
    If we parsed Mints, anyone could create coins, since we don't verify the reason for their creation.

    I'd like to thank you for the effort if you wanted to contribute.
    If you wanted to know the format for you own work, I'd like to thank you for expanding the ecosystem.

    Don't parse Mints.
    --Luke Parker
"""

#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Raw lib.
import ../../../lib/Raw

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Entry and Mint objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/MintObj

#Serialize common functions.
import ../SerializeCommon

#Parse a Mint.
proc parseMint*(
    mintStr: string
): Mint {.forceCheck: [
    ValueError,
    BLSError
].} =
    var
        #Nonce | Output | Amount
        mintSeq: seq[string] = mintStr.deserialize(
            INT_LEN,
            BLS_PUBLIC_KEY_LEN,
            MEROS_LEN
        )
        #Get the nonce.
        nonce: int = mintSeq[0].fromBinary()
        #Output.
        output: BLSPublicKey
        #Get the amount.
        amount: BN = mintSeq[2].toBNFromRaw()

    #Parse the output.
    try:
        output = newBLSPublicKey(mintSeq[1])
    except BLSError as e:
        raise e

    #Create the Mint.
    result = newMintObj(
        output,
        amount
    )
    try:
        #Set the nonce.
        result.nonce = nonce
        #Set the hash.
        result.hash = Blake384(mintStr)
    except ValueError as e:
        raise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Mint: " & e.msg)
