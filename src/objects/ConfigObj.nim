discard """
These are the config options for the node, which are sourced from three places.
First. there's a set of default paramters.
Second, there's a `settings.json` file.
Finally, there's CLI options.
CLI options will override options from the settings file which will override the default paramters.
"""

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

#Constructor.
proc newConfig*(): Config =
    var
        miner: MinerWallet = nil
        tcpPort: uint = 5132
        rpcPort: uint = 5133

    #If the settings file exists...
    if fileExists("./settings.json"):
        #Parse it.
        var json: JSONNode = parseJSON(readFile("./settings.json"))

        #Read its settings.
        if json.hasKey("miner"):
            if json["miner"].kind != JString:
                raise newException(ValueError, "Invalid `miner` setting in the settings file.")
            miner = newMinerWallet(newBLSPrivateKeyFromBytes(json["miner"].getStr()))

        if json.hasKey("tcpPort"):
            if json["tcpPort"].kind != JInt:
                raise newException(ValueError, "Invalid `tcp` setting in the settings file.")
            tcpPort = uint(json["tcpPort"].getInt())

        if json.hasKey("rpcPort"):
            if json["rpcPort"].kind != JInt:
                raise newException(ValueError, "Invalid `rpc` setting in the settings file.")
            rpcPort = uint(json["rpcPort"].getInt())

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
                    miner = newMinerWallet(newBLSPrivateKeyFromBytes(paramStr(i + 1)))

                of "--tcpPort":
                    tcpPort = parseUInt(paramStr(i + 1))

                of "--rpcPort":
                    rpcPort = parseUInt(paramStr(i + 1))

    #Create the config.
    result = Config(
        miner: miner,
        tcpPort: tcpPort,
        rpcPort: rpcPort
    )
