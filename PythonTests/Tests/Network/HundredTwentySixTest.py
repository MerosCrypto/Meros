#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#TestError Exception.
from PythonTests.Tests.Errors import TestError

def HundredTwentySixTest(
    rpc: RPC
) -> None:
    #Handshake with the node using a bull Block hash so it starts syncing.
    rpc.meros.connect(254, 254, bytes.fromhex("FF" * 32))

    #Verify Meros starts syncing.
    if rpc.meros.recv() != MessageType.Syncing.toByte():
        raise TestError("Meros tried to start syncing.")

    #Start syncing on our end.
    rpc.meros.syncing()

    #Verify Meros stops syncing.
    if rpc.meros.recv() != MessageType.SyncingOver.toByte():
        raise TestError("Meros didn't stop syncing.")
