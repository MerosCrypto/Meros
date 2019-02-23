discard """
These are the config options for the node, which are sourced from three places.
First. there's a set of default paramters.
Second, there's a `settings.json` file.
Finally, there's CLI options.
CLI options will override options from the settings file which will override the default paramters.
"""

#Errors lib.
import ../lib/Errors

#BLS lib.
import ../lib/BLS

#MinerWallet lib.
import ../Wallet/MinerWallet

#OS standard lib.
import os

#String utils standard lib.
import strutils

#JSON standard lib.
import json

type Config* = ref object of RootObj
    #MinerWallet to verify transactions with.
    miner*: MinerWallet

    #Port for our server to listen on.
    tcpPort*: uint

    #Port for the RPC to listen on.
    rpcPort*: uint

#Returns if the key exists, after checking the value's type.
proc check(json: JSONNode, key: string, kind: JSONNodeKind): bool {.raises: [ValueError].} =
    result = false

    if json.hasKey(key):
        if json[key].kind != kind:
            raise newException(ValueError, "Invalid `" & key & "` setting in the settings file.")
        return true

#Constructor.
proc newConfig*(): Config {.raises: [ValueError, IndexError, BLSError].} =
    #Create the config.
    result = Config(
        miner: nil,
        tcpPort: 5132,
        rpcPort: 5133
    )

    #If the settings file exists...
    if fileExists("./settings.json"):
        #Parse it.
        var json: JSONNode
        try:
            json = parseJSON(readFile("./settings.json"))
        except:
            raise newException(ValueError, "Invalid settings file.")

        #Read its settings.
        if json.check("miner", JString):
            result.miner = newMinerWallet(newBLSPrivateKeyFromBytes(json["miner"].getStr()))

        if json.check("tcp", JInt):
            result.tcpPort = uint(json["tcpPort"].getInt())

        if json.check("rpc", JInt):
            result.rpcPort = uint(json["rpcPort"].getInt())

    #If there are params...
    if paramCount() > 0:
        #Make sure there's an even amount of params.
        if paramCount() mod 2 != 0:
            raise newException(ValueError, "Invalid amount of arguments.")

        #Iterate over each param.
        for i in countup(1, paramCount(), 2):
            #Switch based off the param.
            case paramStr(i):
                of "--miner":
                    result.miner = newMinerWallet(newBLSPrivateKeyFromBytes(paramStr(i + 1)))

                of "--tcpPort":
                    result.tcpPort = parseUInt(paramStr(i + 1))

                of "--rpcPort":
                    result.rpcPort = parseUInt(paramStr(i + 1))
