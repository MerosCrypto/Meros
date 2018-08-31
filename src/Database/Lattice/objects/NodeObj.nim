#Number libs.
import BN
import ../../../lib/Base

type
    DescendantType* {.pure.} = enum
        NodeSend = 1,
        NodeReceive = 2,
        NodeData = 3,
        NodeVerification = 4,
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
proc setSender*(node: Node, sender: string): bool {.raises: [].} =
    result = true
    if node.sender.len != 0:
        return false

    node.sender = sender

#Set the Node nonce.
proc setNonce*(node: Node, nonce: BN): bool {.raises: [].} =
    result = true
    if not node.nonce.isNil:
        return false

    node.nonce = nonce

#Set the Node hash.
proc setHash*(node: Node, hash: string): bool {.raises: [].} =
    result = true
    if node.hash.len != 0:
        return false

    node.hash = hash

#Set the Node signature.
proc setSignature*(node: Node, signature: string): bool {.raises: [].} =
    result = true
    if not ((node.signature.isNil) or (not signature.isBase(16))):
        return false

    node.signature = signature

#Getters.
proc getSender*(node: Node): string {.raises: [].} =
    node.sender
proc getNonce*(node: Node): BN {.raises: [].} =
    node.nonce
proc getHash*(node: Node): string {.raises: [].} =
    node.hash
proc getSignature*(node: Node): string {.raises: [].} =
    node.signature
