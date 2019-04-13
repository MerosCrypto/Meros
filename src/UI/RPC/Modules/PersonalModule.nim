#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Lattice lib.
import ../../../Database/Lattice/Lattice

#Message object.
import ../../../Network/objects/MessageObj

#Serialization libs.
import ../../../Network/Serialize/Lattice/SerializeSend
import ../../../Network/Serialize/Lattice/SerializeReceive
import ../../../Network/Serialize/Lattice/SerializeData

#RPC object.
import ../objects/RPCObj

#Finals lib.
import finals

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Get the Wallet info.
proc getWallet(rpc: RPC): JSONNode {.raises: [EventError, PersonalError].} =
    var wallet: Wallet
    try:
        wallet = rpc.functions.personal.getWallet()
    except:
        raise newException(EventError, "Couldn't get and call personal.getWallet.")
    if wallet == nil:
        raise newException(PersonalError, "Personal doesn't have a Wallet.")

    result = %* {
        "seed": $wallet.seed,
        "publicKey": $wallet.publicKey,
        "address": wallet.address
    }

#Set the Wallet's Seed.
#The RPC method is set. Set is a keyword. The Nim func is therefore expanded to setPrivateKey.
proc setSeed(
    rpc: RPC,
    seed: string
): JSONNode {.raises: [
    EventError,
].} =
    try:
        rpc.functions.personal.setSeed(seed)
    except:
        raise newException(EventError, "Couldn't get and call personal.setSeed.")

#Create a Send Entry.
proc send(
    rpc: RPC,
    address: string,
    amount: BN,
    nonce: int
): JSONNode {.raises: [
    ValueError,
    EventError,
    AsyncError,
    ArgonError,
    BLSError,
    SodiumError,
    LMDBError,
    FinalAttributeError
].} =
    #Create the Send.
    var send: Send = newSend(
        address,
        amount,
        nonce
    )
    #Sign the Send.
    rpc.functions.personal.signSend(send)
    #Mine the Send.
    send.mine("aa".repeat(48).toBN(16))

    #Add it.
    if not rpc.functions.lattice.addSend(send):
        raise newException(EventError, "Couldn't get and call lattice.send.")

    #Broadcast the Send.
    try:
        asyncCheck rpc.functions.network.broadcast(MessageType.Send, send.serialize())
    except:
        echo "Failed to broadcast the Send."

    result = %* {
        "hash": $send.hash
    }

#Create a Receive Entry.
proc receive(
    rpc: RPC,
    address: string,
    inputNonce: int,
    nonce: int
): JSONNode {.raises: [
    ValueError,
    EventError,
    AsyncError,
    BLSError,
    SodiumError,
    LMDBError,
    FinalAttributeError
].} =
    #Create the Receive.
    var recv: Receive = newReceive(
        newIndex(
            address,
            inputNonce,
        ),
        nonce
    )

    #Sign the Receive.
    try:
        rpc.functions.personal.signReceive(recv)
    except:
        raise newException(EventError, "Couldn't get and call personal.signReceive.")

    #Add it.
    if not rpc.functions.lattice.addReceive(recv):
        raise newException(EventError, "Couldn't get and call lattice.receive.")

    #Broadcast the Receive.
    try:
        asyncCheck rpc.functions.network.broadcast(MessageType.Receive, recv.serialize())
    except:
        echo "Failed to broadcast the Receive."

    result = %* {
        "hash": $recv.hash
    }

#Create a Data Entry.
proc data(
    rpc: RPC,
    dataArg: string,
    nonce: int
): JSONNode {.raises: [
    ValueError,
    EventError,
    AsyncError,
    ArgonError,
    BLSError,
    SodiumError,
    LMDBError,
    FinalAttributeError
].} =
    #Create the Data.
    var data: Data = newData(
        dataArg,
        nonce
    )
    #Sign the Data.
    rpc.functions.personal.signData(data)
    #Mine the Data.
    data.mine("E0".repeat(48).toBN(16))

    #Add it.
    if not rpc.functions.lattice.addData(data):
        raise newException(EventError, "Couldn't get and call lattice.data.")

    #Broadcast the Data.
    try:
        asyncCheck rpc.functions.network.broadcast(MessageType.Data, data.serialize())
    except:
        echo "Failed to broadcast the Data."

    result = %* {
        "hash": $data.hash
    }

#Handler.
proc personalModule*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.async.} =
    #Declare a var for the response.
    var res: JSONNode

    #Put this in a try/catch in case the method fails.
    try:
        #Switch based off the method.
        case json["method"].getStr():
            of "setSeed":
                res = rpc.setSeed(json["args"][0].getStr())

            of "getWallet":
                res = rpc.getWallet()

            of "send":
                res = rpc.send(
                    json["args"][0].getStr(),
                    newBN(json["args"][1].getStr()),
                    parseUInt(json["args"][2].getStr())
                )

            of "receive":
                res = rpc.receive(
                    json["args"][0].getStr(),
                    parseUInt(json["args"][1].getStr()),
                    parseUInt(json["args"][2].getStr())
                )

            of "data":
                res = rpc.data(
                    parseHexStr(json["args"][0].getStr()),
                    parseUInt(json["args"][1].getStr())
                )

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
