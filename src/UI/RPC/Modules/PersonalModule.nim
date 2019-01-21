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

#EventEmitter lib.
import mc_events

#Finals lib.
import finals

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Get the Wallet info.
func getWallet(rpc: RPC): JSONNode {.raises: [EventError, PersonalError].} =
    var wallet: Wallet
    try:
        wallet = rpc.events.get(
            proc (): Wallet,
            "personal.getWallet"
        )()
    except:
        raise newException(EventError, "Couldn't get and call personal.get.")
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
        rpc.events.get(
            proc (seed: string),
            "personal.setSeed"
        )(seed)
    except:
        raise newException(EventError, "Couldn't get and call personal.setSeed.")

#Create a Send Entry.
proc send(
    rpc: RPC,
    address: string,
    amount: BN,
    nonce: uint
): JSONNode {.raises: [
    ValueError,
    ArgonError,
    PersonalError,
    EventError,
    FinalAttributeError
].} =
    #Create the Send.
    var send: Send = newSend(
        address,
        amount,
        nonce
    )
    #Mine the Send.
    send.mine("aa".repeat(64).toBN(16))

    #Sign the Send.
    var sign: proc(send: Send): bool
    try:
        sign = rpc.events.get(
            proc (send: Send): bool,
            "personal.signSend"
        )
    except:
        raise newException(EventError, "Couldn't get and call personal.signSend.")
    try:
        if not send.sign():
            raise newException(Exception, "")
    except:
        raise newException(PersonalError, "Couldn't sign the Send.")

    try:
        #Add it.
        if not rpc.events.get(
            proc (send: Send): bool,
            "lattice.send"
        )(send):
            raise newException(Exception, "")
    except:
        raise newException(EventError, "Couldn't get and call lattice.send.")

    #Broadcast the Send.
    try:
        rpc.events.get(
            proc (msgType: MessageType, msg: string),
            "network.broadcast"
        )(MessageType.Send, send.serialize())
    except:
        echo "Failed to broadcast the Send."


    result = %* {
        "hash": $send.hash
    }

#Create a Receive Entry.
proc receive(
    rpc: RPC,
    address: string,
    inputNonce: uint,
    nonce: uint
): JSONNode {.raises: [
    ValueError,
    EventError,
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
    var sign: proc(recv: Receive)
    try:
        sign = rpc.events.get(
            proc (recv: Receive),
            "personal.signReceive"
        )
        recv.sign()
    except:
        raise newException(EventError, "Couldn't get and call personal.signReceive.")

    try:
        #Add it.
        if not rpc.events.get(
            proc (recv: Receive): bool,
            "lattice.receive"
        )(recv):
            raise newException(Exception, "")
    except:
        raise newException(EventError, "Couldn't get and call lattice.receive.")

    #Broadcast the Receive.
    try:
        rpc.events.get(
            proc (msgType: MessageType, msg: string),
            "network.broadcast"
        )(MessageType.Receive, recv.serialize())
    except:
        echo "Failed to broadcast the Receive."

    result = %* {
        "hash": $recv.hash
    }

#Create a Data Entry.
proc data(
    rpc: RPC,
    dataArg: string,
    nonce: uint
): JSONNode {.raises: [
    ValueError,
    ArgonError,
    PersonalError,
    EventError,
    FinalAttributeError
].} =
    #Create the Data.
    var data: Data = newData(
        dataArg,
        nonce
    )
    #Mine the Data.
    data.mine("E0".repeat(64).toBN(16))

    #Sign the Data.
    var sign: proc(data: Data): bool
    try:
        sign = rpc.events.get(
            proc (data: Data): bool,
            "personal.signData"
        )
    except:
        raise newException(EventError, "Couldn't get and call personal.signData.")
    try:
        if not data.sign():
            raise newException(Exception, "")
    except:
        raise newException(PersonalError, "Couldn't sign the Send.")

    try:
        #Add it.
        if not rpc.events.get(
            proc (data: Data): bool,
            "lattice.data"
        )(data):
            raise newException(Exception, "")
    except:
        raise newException(EventError, "Couldn't get and call lattice.data.")

    #Broadcast the Data.
    try:
        rpc.events.get(
            proc (msgType: MessageType, msg: string),
            "network.broadcast"
        )(MessageType.Data, data.serialize())
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
