#[
These are the config options for the node, which are sourced from three places.
First. there's a set of default paramters.
Second, there's a `settings.json` file.
Finally, there are CLI options.
CLI options will override options from the settings file which will override the default paramters.
]#

#Errors lib.
import ../lib/Errors

#Utils lib.
import ../lib/Util

#OS standard lib.
import os

#String utils standard lib.
import strutils

#Tables standard lib.
import tables

#JSON standard lib.
import json

const
    #Help test.
    HELP_TEXT: string = """
Meros Full Node v0.6.1.
Parameters can be specified over the CLI or via a JSON file, named
`settings.json`, placed in the data directory.

OPTIONS:
    -h,  --help                       Prints this help.
    -d,  --data-dir  <DATA_DIRECTORY> Directory to store data in.
    -l,  --log-file  <LOG_FILE>       File to save the log to.
         --db        <DB_NAME>        Name for the database file.
    -n,  --network   <NETWORK>        Network to connect to.
    -ns, --no-server                  Don't accept incoming connections.
    -t,  --tcp-port  <PORT>           Port to listen for connections on.
    -r,  --rpc-port  <PORT>           Port the RPC should listen on.
    -ng, --no-gui                     Don't start the GUI."""

    #Table of which long parameter a short parameter represents.
    shortParams: Table[string, string] = {
        "h":  "help",
        "d":  "data-dir",
        "l":  "log-file",
        "n":  "network",
        "ns": "no-server",
        "t":  "tcp-port",
        "r":  "rpc-port",
        "ng": "no-gui"
    }.toTable()

    #Table of how many arguments each parameter takes.
    longParams: Table[string, int] = {
        "data-dir":  1,
        "log-file":  1,
        "db":        1,
        "network":   1,
        "no-server": 0,
        "tcp-port":  1,
        "rpc-port":  1,
        "no-gui":    0
    }.toTable()

type Config* = object
    #Data Directory.
    dataDir*: string
    #Log file.
    logFile*: string
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

#Returns the key if it exists and matches the passed type.
proc get(
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

    #Parse the command line options.
    var
        options: Table[string, seq[string]] = initTable[string, seq[string]]()
        param: string
        value: string
        length: int
        p: int = 1
    while p <= paramCount():
        try:
            #Skip "" parameters.
            if paramStr(p).len == 0:
                inc(p)
                continue
            value = paramStr(p)
        except IndexError:
            doAssert(false, "Couldn't get a parameter.")

        #Make sure this isn't "-".
        if value.len == 1:
            echo value, " is too short to be a valid parameter. Please run --help for more info."
            quit(0)

        #Check for shortened paramters.
        if (value[0] == '-') and (value[1] != '-'):
            #Grab the shortened parameter.
            try:
                param = shortParams[value[1 ..< value.len]]
            except KeyError:
                echo value, " is not a valid shortened parameter. Please run --help for more info."
                quit(0)
        #Check for long parameters.
        elif value[0 ..< 2] == "--":
            param = value[2 ..< value.len]
        else:
            echo "An argument was provided as the first parameter."
            quit(0)

        #If the parameter is help, print the help text and quit.
        if param == "help":
            echo HELP_TEXT
            quit(0)

        #Grab the amount of arguments for this parameter.
        try:
            length = longParams[param]
        except KeyError:
            echo value, " is not a valid parameter. Please run --help for more info."
            quit(0)

        #Parse out the arguments.
        options[param] = newSeq[string](length)
        for a in 0 ..< length:
            try:
                #Move from the parameter to the argument.
                inc(p)

                #Skip "" parameters.
                while paramStr(p).len == 0:
                    inc(p)

                #Verify this is actually an argument.
                if paramStr(p)[0] == '-':
                    echo param, " was not given enough arguments. Please run --help for more info."
                    quit(0)

                try:
                    options[param][a] = paramStr(p)
                except KeyError as e:
                    doAssert(false, "Couldn't add an argument to a parameter despite creating a seq for it: " & e.msg)
            except IndexError:
                echo param, " was not given enough arguments. Please run --help for more info."
                quit(0)

        #Increment to the next parameter.
        inc(p)
        #Verify the next parameter isn't another argument for the previous parameter.
        try:
            #Skip "" parameters.
            while paramStr(p).len == 0:
                inc(p)

            if paramStr(p)[0] != '-':
                echo param, " was given too many arguments. Please run --help for more info."
                quit(0)
        except IndexError:
            #We reached the end of the arguments.
            discard

    #Set the dataDir parameter, if it was passed.
    if options.hasKey("data-dir"):
        try:
            result.dataDir = options["data-dir"][0]
        except KeyError as e:
            doAssert(false, "Couldn't grab a key from the options we're confirmed to have: " & e.msg)

    #Declare a JSON object for the settings file.
    var settings: JSONNode = newJObject()
    #If the settings file exists, load it.
    if fileExists(result.dataDir / "settings.json"):
        #Parse it.
        try:
            settings = parseJSON(readFile(result.dataDir / "settings.json"))
        except Exception as e:
            doAssert(false, "Either couldn't read or parse the settings file despite it existing: " & e.msg)

    #Handle the settings.
    template setParameter[X](
        variable: var X,
        parameter: string,
        value: untyped,
        overrideValue: untyped
    ): untyped =
        try:
            variable = value
        except ValueError:
            echo "Invalid ", parameter, " value in the JSON settings. Please run --help for more info."
            quit(0)
        except IndexError:
            discard

        try:
            variable = overrideValue
        except KeyError:
            discard
        except ValueError:
            echo "Invalid ", parameter, " value passed over the CLI. Please run --help for more info."
            quit(0)

    result.db.setParameter(
        "db",
        settings.get("db", JString).getStr(),
        options["db"][0]
    )

    result.network.setParameter(
        "network",
        settings.get("network", JString).getStr(),
        options["network"][0]
    )

    result.logFile &= result.network & ".log"
    result.logFile.setParameter(
        "log-file",
        settings.get("log-file", JString).getStr(),
        options["log-file"][0]
    )

    if options.hasKey("no-server"):
        result.server = false
    else:
        result.server.setParameter(
            "no-server",
            not settings.get("no-server", JBool).getBool(),
            parseBool(options["no-server"][0])
        )

    result.tcpPort.setParameter(
        "tcp-port",
        settings.get("tcp-port", JInt).getInt(),
        int(parseUInt(options["tcp-port"][0]))
    )

    result.rpcPort.setParameter(
        "rpc-port",
        settings.get("rpc-port", JInt).getInt(),
        int(parseUInt(options["rpc-port"][0]))
    )

    if options.hasKey("no-gui"):
        result.gui = false
    else:
        result.gui.setParameter(
            "no-gui",
            not settings.get("no-gui", JBool).getBool(),
            parseBool(options["no-gui"][0])
        )

    #Make sure the data directory exists.
    try:
        var dirs: seq[string] = result.dataDir.split("/")
        for d in 0 ..< dirs.len:
            discard existsOrCreateDir(dirs[0 .. d].joinPath())
    except OSError as e:
        doAssert(false, "Couldn't create the data directory due to an OSError: " & e.msg)
    except IOError as e:
        doAssert(false, "Couldn't create the data directory due to an IOError: " & e.msg)
