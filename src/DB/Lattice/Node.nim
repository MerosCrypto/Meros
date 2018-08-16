#Number libs.
import ../../lib/BN
import ../../lib/Base

type Node* = ref object of RootObj
    #Type of descendant.
    descendant: int
    #Index on the account.
    nonce: BN
    #Node hash.
    hash: string
    #Signature.
    signature: string

#Set the Node descendant
proc setDescendant*(node: Node, descendant: int): bool =
    result = true
    if node.descendant != 0:
        result = false
        return

    node.descendant = descendant

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
    if (not node.hash.isNil) or (not hash.isBase(16)):
        result = false
        return

    node.hash = hash

#Set the Node signature.
proc setSignature*(node: Node, signature: string): bool =
    result = true
    if not node.signature.isNil:
        result = false
        return

    node.signature = signature

#Getters.
proc getDescendant*(node: Node): int =
    node.descendant
proc getNonce*(node: Node): BN =
    node.nonce
proc getHash*(node: Node): string =
    node.hash
proc getSignature*(node: Node): string =
    node.signature
