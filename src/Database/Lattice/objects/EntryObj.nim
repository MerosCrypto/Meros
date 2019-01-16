#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals

finalsd:
    type
        #Enum of the various Entry Types.
        EntryType* = enum
            Mint = 0,
            Claim = 1,
            Send = 2,
            Receive = 3,
            Data = 4

        #Entry object.
        Entry* = ref object of RootObj
            #Type of descendant.
            descendant* {.final.}: EntryType
            #Address behind the Entry.
            sender* {.final.}: string
            #Index on the account.
            nonce* {.final.}: uint
            #Hash.
            hash* {.final.}: Hash[512]
            #Signature.
            signature* {.final.}: string
            #Verified.
            verified*: bool
