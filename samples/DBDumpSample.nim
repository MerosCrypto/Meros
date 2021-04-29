import strutils
import sets
import json
import httpclient

type MerosError = object of CatchableError

var
  db: JSONNode = %* {
    "blockchain": [],
    "transactions": {}
  }
  hashes: HashSet[string] = initHashSet[string]()

proc call(
  module: string,
  methodStr: string,
  params: JSONNode = %* {}
): JSONNode =
  var
    client: HttpClient = newHttpClient()
    res: JSONNode = parseJSON(
      client.request(
        "http://localhost:5133",
        "POST",
        $ %* {
          "jsonrpc": "2.0",
          "id": 0,
          "method": module & "_" & methodStr,
          "params": params
        }
      ).body
    )
  if res.hasKey("error"):
    raise newException(MerosError, "RPC threw an error: " & $res["error"])
  result = res["result"]
  client.close()

#Get every Block.
for nonce in 0 ..< call("merit", "getHeight").getInt():
  db["blockchain"].add(call("merit", "getBlock", %* {"block": nonce}))

  #Get the matching Mint.
  try:
    db["transactions"][
      db["blockchain"][db["blockchain"].len - 1]["hash"].getStr()
    ] = call("transactions", "getTransaction", % {"hash": db["blockchain"][db["blockchain"].len - 1]["hash"]})
  #This will raise if there wasn't a Mint for this Block.
  except MerosError:
    discard

  #Mark every Transaction so we can grab them later.
  for tx in db["blockchain"][db["blockchain"].len - 1]["transactions"]:
    hashes.incl(tx["hash"].getStr())

#Get every Transaction.
for hash in hashes:
  db["transactions"][hash.toHex()] = call("transactions", "getTransaction", %* {"hash": hash})

#Write it to a file.
"data/db.json".writeFile(db.pretty(4))
