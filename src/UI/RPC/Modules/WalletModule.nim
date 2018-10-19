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

#Get the Wallet info.
func get(rpc: RPC): JSONNode {.raises: [PersonalError].} =
    if rpc.wallet == nil:
        raise newException(PersonalError, "RPC doesn't have a Wallet.")

    result = %* {
        "seed": $rpc.wallet.seed,
        "publicKey": $rpc.wallet.publicKey,
        "address": rpc.wallet.address
    }

#Set the Wallet's Seed.
#The RPC method is set. Set is a keyword. The Nim func is therefore expanded to setPrivateKey.
proc setSeed(
    rpc: RPC,
    seed: string
): JSONNode {.raises: [
    ValueError,
    RandomError,
    SodiumError,
    PersonalError
].} =
    if seed.len == 0:
        rpc.wallet = newWallet()
    else:
        rpc.wallet = newWallet(newEdSeed(seed))

    result = rpc.get()

#Handler.
proc `walletModule`*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.raises: [].} =
    #Declare a var for the response.
    var res: JSONNode

    #Put this in a try/catch in case the method fails.
    try:
        #Switch based off the method.
        case json["method"].getStr():
            of "set":
                res = rpc.setSeed(json["args"][0].getStr())

            of "get":
                res = rpc.get()

            else:
                res = %* {
                    "error": "Invalid method."
                }
    except:
        #If there was an issue, make the response the error message.
        res = %* {
            "error": getCurrentExceptionMsg()
        }

    reply(res)
