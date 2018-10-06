#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals


finalsd:
    type
        #Enum of the various Node Types.
        NodeType* = enum
            Send = 0,
            Receive = 1,
            Data = 2,
            Verification = 3,
            MeritRemoval = 4

        #Node object.
        Node* = ref object of RootObj
            #Type of descendant.
            descendant* {.final.}: NodeType
            #Address behind the node.
            sender* {.final.}: string
            #Index on the account.
            nonce* {.final.}: BN
            #Node hash.
            hash* {.final.}: Hash[512]
            #Signature.
            signature* {.final.}: string
            #Verified.
            verified*: bool
