include MainNetwork

var
  fromMain: Channel[string] #Channel from the 'main' thread to the Interfaces thread.
  toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
  toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.

#Open the channels.
fromMain.open()
toRPC.open()
toGUI.open()

proc mainRPC(
  config: Config,
  functions: GlobalFunctionBox,
  rpc: var RPC
) {.forceCheck: [].} =
  #Don't bother if we'll never get any requests.
  if not (config.rpc or config.gui):
    return

  var token: string
  if config.rpc:
    #Grab the token if one was passed.
    if config.token.isSome():
      token = config.token.unsafeGet()
    #Generate one.
    else:
      token = newString(32)
      randomFill(token)
      token = token.toHex()

      try:
        let tokenFile: File = open(config.dataDir / ".token", fmWrite)
        tokenFile.write(token)
        tokenFile.close()
      except IOError as e:
        panic("Couldn't write the RPC token to .token, under the data directory: " & e.msg)

  rpc = newRPC(functions, addr toRPC, addr toGUI, token)

  try:
    #Start even if the RPC is disabled so we can still serve the RPC.
    asyncCheck rpc.start()
    if config.rpc:
      asyncCheck rpc.listen(config)
  except Exception as e:
    panic("Couldn't start the RPC: " & e.msg)

when not defined(nogui):
  proc mainGUI() {.forceCheck: [].} =
    newGUI(addr fromMain, addr toRPC, addr toGUI, 800, 500)
