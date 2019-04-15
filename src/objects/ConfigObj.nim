discard """
These are the config options for the node, which are sourced from three places.
First. there's a set of default paramters.
Second, there's a `settings.json` file.
Finally, there are CLI options.
CLI options will override options from the settings file which will override the default paramters.
"""

#Errors lib.
import ../lib/Errors

#Utils lib.
import ../lib/Util

#MinerWallet lib.
import ../Wallet/MinerWallet

#OS standard lib.
import os

#JSON standard lib.
import json

type Config* = object
    #DB Path.
    db*: string

    #Port for our server to listen on.
    tcpPort*: int
    #Port for the RPC to listen on.
    rpcPort*: int

    #MinerWallet to verify transactions with.
    miner*: MinerWallet

#Returns the key if it exists and matches the passed type.
func get(
    json: JSONNode,
    key: string,
    kind: JSONNodeKind
): JSONNode {.forceCheck: [
    ValueError,
    IndexError
].} =
    if json.hasKey(key):
        try:
            if json[key].kind != kind:
                raise newException(ValueError, "Invalid `" & key & "` type in the settings file.")
            return json[key]
        except KeyError as e:
            doAssert(false, "Couldn't get a JSON field despite confirming it exists: " & e.msg)
    raise newException(IndexError, "Key is not present in this JSON.")


#Constructor.
proc newConfig*(): Config {.forceCheck: [
    ValueError,
    Errors.JSONError,
    RandomError,
    BLSError
].} =
    #Create the config with the default options.
    try:
        result = Config(
            db: "./data/db",
            tcpPort: 5132,
            rpcPort: 5133
        )
    except RandomError as e:
        raise e
    except BLSError as e:
        raise e

    #If the settings file exists...
    if fileExists("./data/settings.json"):
        #Parse it.
        var
            settings: string
            json: JSONNode
        try:
            settings = readFile("./data/settings.json")
        except Exception as e:
            raise newException(Errors.JSONError, "Couldn't read from `./data/settings.json` despite it existing: " & e.msg)
        try:
            json = parseJSON(settings)
        except Exception as e:
            raise newException(Errors.JSONError, "Couldn't parse `./data/settings.json` despite it existing: " & e.msg)

        #Handle the settings.
        try:
            result.db = json.get("db", JString).getStr()
        except ValueError as e:
            raise e
        except IndexError:
            discard

        try:
            result.tcpPort = json.get("tcpPort", JInt).getInt()
        except ValueError as e:
            raise e
        except IndexError:
            discard

        try:
            result.rpcPort = json.get("rpcPort", JInt).getInt()
        except ValueError as e:
            raise e
        except IndexError:
            discard

        try:
            result.miner = newMinerWallet(
                newBLSPrivateKeyFromBytes(
                    json.get("miner", JInt).getStr()
                )
            )
        except ValueError as e:
            raise e
        except IndexError:
            discard
        except BLSError as e:
            raise e

    #If there are params...
    if paramCount() > 0:
        #Make sure there's an even amount of params.
        if paramCount() mod 2 != 0:
            raise newException(ValueError, "Invalid amount of arguments.")

        #Iterate over each param.
        try:
            for i in countup(1, paramCount(), 2):
                #Switch based off the param.
                case paramStr(i):
                    of "--db":
                        result.db = paramStr(i + 1)

                    of "--tcpPort":
                        result.tcpPort = parseInt(paramStr(i + 1))

                    of "--rpcPort":
                        result.rpcPort = parseInt(paramStr(i + 1))

                    of "--miner":
                        try:
                            result.miner = newMinerWallet(
                                newBLSPrivateKeyFromBytes(
                                    paramStr(i + 1)
                                )
                            )
                        except BLSError as e:
                            raise e
        except ValueError as e:
            raise e
        except IndexError as e:
            doAssert(false, "Exceeded paramCount despite counting up to it: " & e.msg)
