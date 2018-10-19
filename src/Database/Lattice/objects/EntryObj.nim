#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals

finalsd:
    type
        #Enum of the various Entry Types.
        EntryType* = enum
            Send = 0,
            Receive = 1,
            Data = 2,
            MeritRemoval = 3

        #Entry object.
        Entry* = ref object of RootObj
            #Type of descendant.
            descendant* {.final.}: EntryType
            #Address behind the Entry.
            sender* {.final.}: string
            #Index on the account.
            nonce* {.final.}: uint
            #Entry hash.
            hash* {.final.}: Hash[512]
            #Signature.
            signature* {.final.}: string
            #Verified.
            verified*: bool
