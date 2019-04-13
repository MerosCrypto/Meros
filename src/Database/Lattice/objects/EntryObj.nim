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
            #Nonce on the account.
            nonce* {.final.}: Natural
            #Hash.
            hash* {.final.}: Hash[384]
            #Signature.
            signature* {.final.}: string
            #Verified.
            verified*: bool
