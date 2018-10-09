#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#RPC object.
import ../objects/RPCObj

#Finals lib.
import finals

#JSON standard lib.
import json

#Set the Wallet's Private Key.
#The RPC method is set. Set is a keyword. The Nim func is therefore expanded to setPrivateKey.
func setPrivateKey(rpc: RPC, privateKey: string): JSONNode {.raises: [ValueError, SodiumError].} =
    if privateKey.len == 0:
        rpc.wallet = newWallet()
    else:
        rpc.wallet = newWallet(newPrivateKey(privateKey))

    result = %* {}

#Get the Wallet info.
proc get(rpc: RPC): JSONNode {.raises: [].} =
    %* {
        "privateKey": $rpc.wallet.privateKey,
        "publicKey": $rpc.wallet.publicKey,
        "address": rpc.wallet.address
    }

#Handler.
proc `walletModule`*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.raises: [ValueError, SodiumError].} =
    #Switch based off the method.
    case json["method"].getStr():
        of "set":
            reply(
                rpc.setPrivateKey(json["args"][0].getStr())
            )
        of "get":
            reply(
                rpc.get()
            )
