#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

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

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Set the Wallet's secret.
proc setSecret(
    rpc: RPC,
    secret: string
): JSONNode {.forceCheck: [].} =
    try:
        rpc.functions.personal.setSecret(secret)
    except ValueError as e:
        returnError()
    except RandomError as e:
        doAssert(secret.len == 0, "personal.setSecret threw a RandomError despite being passed a secret: " & e.msg)
        returnError()

#Get the Wallet info.
proc getWallet(
    rpc: RPC
): JSONNode {.forceCheck: [].} =
    var wallet: Wallet = rpc.functions.personal.getWallet()
    if not wallet.initiated:
        return %* {
            "error": "Personal does not have a Wallet."
        }

    result = %* {
        "privateKey": $wallet.privateKey,
        "publicKey": $wallet.publicKey,
        "address": wallet.address
    }

#Create a Send Entry.
proc send(
    rpc: RPC,
    address: string,
    amount: uint64,
    nonce: int
): JSONNode {.forceCheck: [].} =
    #Create the Send.
    var send: Send
    try:
        send = newSend(
            address,
            amount,
            nonce
        )
    except ValueError as e:
        returnError()
    except AddressError as e:
        returnError()

    #Sign the Send.
    try:
        rpc.functions.personal.signSend(send)
    except AddressError as e:
        doAssert(false, "Couldn't sign the Send we created due to an AddressError (which means it failed to serialize): " & e.msg)

    #Mine the Send.
    try:
        send.mine(rpc.functions.lattice.getDifficulties().send)
    except ValueError as e:
        doAssert(false, "Couldn't mine the Send we created due to an ValueError (meaning it wasn't signed): " & e.msg)
    except ArgonError as e:
        returnError()

    #Add it.
    try:
        rpc.functions.lattice.addSend(send)
    except ValueError as e:
        returnError()
    except IndexError as e:
        returnError()
    except GapError as e:
        returnError()
    except AddressError as e:
        returnError()
    except EdPublicKeyError as e:
        returnError()
    except DataExists as e:
        returnError()

    result = %* {
        "hash": $send.hash
    }

#Create a Receive Entry.
proc receive(
    rpc: RPC,
    address: string,
    inputNonce: int,
    nonce: int
): JSONNode {.forceCheck: [].} =
    #Create the Receive.
    var recv: Receive
    try:
        recv = newReceive(
            newLatticeIndex(
                address,
                inputNonce,
            ),
            nonce
        )
    except AddressError as e:
        doAssert(false, "Couldn't sign the Receive we created due to an AddressError (which means it failed to serialize): " & e.msg)

    #Sign the Receive.
    rpc.functions.personal.signReceive(recv)

    #Add it.
    try:
        rpc.functions.lattice.addReceive(recv)
    except ValueError as e:
        returnError()
    except IndexError as e:
        returnError()
    except GapError as e:
        returnError()
    except AddressError as e:
        returnError()
    except EdPublicKeyError as e:
        returnError()
    except DataExists as e:
        returnError()

    result = %* {
        "hash": $recv.hash
    }

#Create a Data Entry.
proc data(
    rpc: RPC,
    dataArg: string,
    nonce: int
): JSONNode {.forceCheck: [].} =
    #Create the Data.
    var data: Data
    try:
        data = newData(
            dataArg,
            nonce
        )
    except ValueError as e:
        returnError()

    #Sign the Data.
    try:
        rpc.functions.personal.signData(data)
    except AddressError as e:
        doAssert(false, "Couldn't sign the Data we created due to an AddressError (which means it failed to serialize): " & e.msg)

    #Mine the Data.
    try:
        data.mine(rpc.functions.lattice.getDifficulties().data)
    except ValueError as e:
        doAssert(false, "Couldn't mine the Data we created due to an ValueError (meaning it wasn't signed): " & e.msg)
    except ArgonError as e:
        returnError()

    #Add it.
    try:
        rpc.functions.lattice.addData(data):
    except ValueError as e:
        returnError()
    except IndexError as e:
        returnError()
    except GapError as e:
        returnError()
    except AddressError as e:
        returnError()
    except EdPublicKeyError as e:
        returnError()
    except DataExists as e:
        returnError()

    result = %* {
        "hash": $data.hash
    }

#Handler.
proc personal*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (
        json: JSONNode
    ) {.raises: [].}
) {.forceCheck: [], async.} =
    #Declare a var for the response.
    var res: JSONNode

    #Switch based off the method.
    var methodStr: string
    try:
        methodStr = json["method"].getStr()
    except KeyError:
        reply(%* {
            "error": "No method specified."
        })
        return

    try:
        case methodStr:
            of "setSecret":
                if json["args"].len < 1:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.setSecret(json["args"][0].getStr())

            of "getWallet":
                res = rpc.getWallet()

            of "send":
                if json["args"].len < 3:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.send(
                        json["args"][0].getStr(),
                        uint64(parseUInt(json["args"][1].getStr())),
                        json["args"][2].getInt()
                    )

            of "receive":
                if json["args"].len < 3:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.receive(
                        json["args"][0].getStr(),
                        json["args"][1].getInt(),
                        json["args"][2].getInt()
                    )

            of "data":
                if json["args"].len < 2:
                    res = %* {
                        "error": "Not enough args were passed."
                    }
                else:
                    res = rpc.data(
                        json["args"][0].getStr().parseHexStr(),
                        json["args"][1].getInt()
                    )

            else:
                res = %* {
                    "error": "Invalid method."
                }
    except KeyError:
        res = %* {
            "error": "Missing `args`."
        }
    except ValueError:
        res = %* {
            "error": "Invalid hex string passed."
        }

    reply(res)
