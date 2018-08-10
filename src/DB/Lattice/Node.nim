#Number libs.
import ../../lib/BN
import ../../lib/Base

type Node* = ref object of RootObj
    #Index on the account.
    nonce*: BN
    #Block the TX is tied to.
    blockNumber*: BN

    #Node hash.
    hash: string
    #Signature.
    signature: string

#Set the Node hash.
proc setHash*(node: Node, hash: string): bool =
    result = true
    if not hash.isBase(16):
        result = false
        return

    node.hash = hash

#Set the Node signature.
proc setSignature*(node: Node, signature: string) =
    node.signature = signature

#Getters.
proc getHash*(node: Node): string =
    node.hash
proc getSignature*(node: Node): string =
    node.signature
