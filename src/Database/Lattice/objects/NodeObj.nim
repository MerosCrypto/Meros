#Number libs.
import ../../../lib/BN
import ../../../lib/Base

type
    DescendantType* {.pure.} = enum
        NodeSend = 1,
        NodeReceive = 2,
        NodeData = 3,
        Nodeverification = 4,
        NodeMeritRemoval = 5

    Node* = ref object of RootObj
        #Type of descendant.
        descendant*: DescendantType
        #Address behind the node.
        sender: string
        #Index on the account.
        nonce: BN
        #Node hash.
        hash: string
        #Signature.
        signature: string

#Set the sender.
proc setSender*(node: Node, sender: string): bool =
    result = true
    if node.sender.len != 0:
        result = false
        return

    node.sender = sender

#Set the Node nonce.
proc setNonce*(node: Node, nonce: BN): bool =
    result = true
    if not node.nonce.isNil:
        result = false
        return

    node.nonce = nonce

#Set the Node hash.
proc setHash*(node: Node, hash: string): bool =
    result = true
    if node.hash.len != 0:
        result = false
        return

    node.hash = hash

#Set the Node signature.
proc setSignature*(node: Node, signature: string): bool =
    result = true
    if not ((node.signature.isNil) or (not signature.isBase(16))):
        result = false
        return

    node.signature = signature

#Getters.
proc getSender*(node: Node): string =
    node.sender
proc getNonce*(node: Node): BN =
    node.nonce
proc getHash*(node: Node): string =
    node.hash
proc getSignature*(node: Node): string =
    node.signature
