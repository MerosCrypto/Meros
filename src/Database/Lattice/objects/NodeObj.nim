#Number libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

type
    NodeType* = enum
        Send = 0,
        Receive = 1,
        Data = 2,
        Verification = 3,
        MeritRemoval = 4

    Node* = ref object of RootObj
        #Type of descendant.
        descendant*: NodeType
        #Address behind the node.
        sender: string
        #Index on the account.
        nonce: BN
        #Node hash.
        hash: Hash[512]
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
    if not node.nonce.getNil():
        return false

    node.nonce = nonce

#Set the Node hash.
proc setHash*(node: Node, hash: Hash[512]): bool {.raises: [].} =
    result = true
    node.hash = hash

#Set the Node signature.
proc setSignature*(node: Node, signature: string): bool {.raises: [].} =
    result = true
    if (node.signature.len != 0) or (not signature.isBase(16)):
        return false

    node.signature = signature

#Getters.
proc getSender*(node: Node): string {.raises: [].} =
    node.sender
proc getNonce*(node: Node): BN {.raises: [].} =
    node.nonce
proc getHash*(node: Node): Hash[512] {.raises: [].} =
    node.hash
proc getSignature*(node: Node): string {.raises: [].} =
    node.signature
