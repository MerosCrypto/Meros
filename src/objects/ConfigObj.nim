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

#String utils standard lib.
import strutils

#JSON standard lib.
import json

type Config* = object
    #Data Directory.
    dataDir*: string
    #DB Path.
    db*: string

    #Network we're connecting to.
    network*: string

    #Listening for Meros connections or not.
    server*: bool
    #Port for our server to listen on.
    tcpPort*: int
    #Port for the RPC to listen on.
    rpcPort*: int

    #Spawn a GUI or not.
    gui*: bool

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
proc newConfig*(): Config {.forceCheck: [].} =
    #Create the config with the default options.
    result = Config(
        dataDir: "./data",
        db: "db",
        network: "testnet",
        server: true,
        tcpPort: 5132,
        rpcPort: 5133,
        gui: true
    )

    #Check if the data directory was overriden via the CLI.
    #First, confirm the amount of CLI arguments.
    if paramCount() mod 2 != 0:
        doAssert(false, "Invalid amount of arguments passed via the CLI.")

    #Look for the --dataDir switch.
    if paramCount() > 0:
        try:
            for i in countup(1, paramCount(), 2):
                if paramStr(i) == "--dataDir":
                    result.dataDir = paramStr(i + 1)
        except ValueError as e:
            doAssert(false, "Couldn't parse a value passed via the CLI: " & e.msg)
        except IndexError as e:
            doAssert(false, "Exceeded paramCount despite counting up to it: " & e.msg)

    #If the settings file exists...
    if fileExists(result.dataDir / "settings.json"):
        #Parse it.
        var
            settings: string
            json: JSONNode
        try:
            settings = readFile(result.dataDir / "settings.json")
        except Exception as e:
            doAssert(false, "Couldn't read from `" & (result.dataDir / "settings.json") & "` despite it existing: " & e.msg)
        try:
            json = parseJSON(settings)
        except Exception as e:
            doAssert(false, "Couldn't parse `" & (result.dataDir / "settings.json") & "` despite it existing: " & e.msg)

        #Handle the settings.
        try:
            result.db = json.get("db", JString).getStr()
        except ValueError as e:
            doAssert(false, e.msg)
        except IndexError:
            discard

        try:
            result.network = json.get("network", JString).getStr()
        except ValueError as e:
            doAssert(false, e.msg)
        except IndexError:
            discard

        try:
            result.server = json.get("server", JBool).getBool()
        except ValueError as e:
            doAssert(false, e.msg)
        except IndexError:
            discard

        try:
            result.tcpPort = json.get("tcpPort", JInt).getInt()
        except ValueError as e:
            doAssert(false, e.msg)
        except IndexError:
            discard

        try:
            result.rpcPort = json.get("rpcPort", JInt).getInt()
        except ValueError as e:
            doAssert(false, e.msg)
        except IndexError:
            discard

        try:
            result.gui = json.get("gui", JBool).getBool()
        except ValueError as e:
            doAssert(false, e.msg)
        except IndexError:
            discard

        try:
            result.miner = newMinerWallet(
                json.get("miner", JString).getStr()
            )
        except ValueError as e:
            doAssert(false, e.msg)
        except IndexError:
            discard
        except BLSError as e:
            doAssert(false, "Couldn't create a MinerWallet from the value in `" & (result.dataDir / "settings.json") & "`: " & e.msg)

    #If there are params...
    if paramCount() > 0:
        #Iterate over each param.
        try:
            for i in countup(1, paramCount(), 2):
                #Switch based off the param.
                case paramStr(i):
                    of "--db":
                        result.db = paramStr(i + 1)

                    of "--network":
                        result.network = paramStr(i + 1)

                    of "--server":
                        result.server = (paramStr(i + 1) == "true")

                    of "--tcpPort":
                        result.tcpPort = parseInt(paramStr(i + 1))

                    of "--rpcPort":
                        result.rpcPort = parseInt(paramStr(i + 1))

                    of "--gui":
                        result.gui = parseBool(paramStr(i + 1))

                    of "--miner":
                        try:
                            result.miner = newMinerWallet(paramStr(i + 1))
                        except ValueError as e:
                            doAssert(false, "Couldn't create a MinerWallet from the passed value: " & e.msg)
                        except BLSError as e:
                            doAssert(false, "Couldn't create a MinerWallet from the passed value: " & e.msg)
        except ValueError as e:
            doAssert(false, "Couldn't parse a value passed via the CLI: " & e.msg)
        except IndexError as e:
            doAssert(false, "Exceeded paramCount despite counting up to it: " & e.msg)

    #Make sure the data directory exists.
    try:
        var dirs: seq[string] = result.dataDir.split("/")
        for d in 0 ..< dirs.len:
            discard existsOrCreateDir(dirs[0 .. d].joinPath())
    except OSError as e:
        doAssert(false, "Couldn't create the data directory due to an OSError: " & e.msg)
    except IOError as e:
        doAssert(false, "Couldn't create the data directory due to an IOError: " & e.msg)
