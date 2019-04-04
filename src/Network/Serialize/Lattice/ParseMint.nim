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

#Hash lib.
import ../../../lib/Hash

#Numerical libs.
import BN
import ../../../lib/Base

#Entry and Mint objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/MintObj

#Serialize common functions.
import ../SerializeCommon

#Finals lib.
import finals

#Parse a Mint.
proc parseMint*(
    mintStr: string
): Mint {.raises: [
    ValueError,
    FinalAttributeError
].} =
    var
        #Nonce | Output | Amount
        mintSeq: seq[string] = mintStr.deserialize(3)
        #Get the nonce.
        nonce: uint = uint(mintSeq[0].fromBinary())
        #Get the output.
        output: string = mintSeq[1].pad(48)
        #Get the amount.
        amount: BN = mintSeq[2].toBN(256)

    #Create the Mint.
    result = newMintObj(
        output,
        amount
    )
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = Blake512(mintStr)
