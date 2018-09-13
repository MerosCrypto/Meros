#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#SetOnce lib.
import SetOnce

type
    NodeType* = enum
        Send = 0,
        Receive = 1,
        Data = 2,
        Verification = 3,
        MeritRemoval = 4

    Node* = ref object of RootObj
        #Type of descendant.
        descendant*: SetOnce[NodeType]
        #Address behind the node.
        sender*: SetOnce[string]
        #Index on the account.
        nonce*: SetOnce[BN]
        #Node hash.
        hash*: SetOnce[Hash[512]]
        #Signature.
        signature*: SetOnce[string]
