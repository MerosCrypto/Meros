#Include the Second file in the chain, NetworkCore.
include NetworkCore

#Request a Block.
proc requestBlock*(network: Network, nonce: uint) {.async.} =
    #If we use the .items iterator, we gain two advantages.
    #The first is that since we can only directly index by ID, we don't have to track that.
    #The second is that we only run if we have a client.
    for client in network.clients:
        #Start syncing.
        client.sync()
        #Get the Block.
        var requested: Block = await client.syncBlock(nonce)
        #Stop syncing.
        client.syncOver()
        #Notify MainMerit.
        discard await network.mainFunctions.merit.addBlock(requested)
        #Return to prevent running multiple times.
        return

#Sync a Block's Verifications/Entries.
proc sync*(network: Network, newBlock: Block): Future[bool] {.async.} =
    for client in network.clients:
        result = true

        #Return so we don't run again with a new Client.
        return
