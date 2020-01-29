#https://github.com/MerosCrypto/Meros/issues/123.

#RPC class.
from PythonTests.Meros.RPC import RPC

#EmptyError Exception.
from PythonTests.Tests.Errors import EmptyError

a = """
#Types.
from typing import Dict, List, IO, Any

#Transactions classes.
from PythonTests.Classes.Transactions.Data import Data
from PythonTests.Classes.Transactions.Transactions import Transactions

#Element classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver
from PythonTests.Meros.Syncer import Syncer

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#JSON standard lib.
import json
"""

def HundredTwentyThreeTest(
    rpc: RPC
) -> None:
    b = """
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/HundredTwentyThreeTest.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    keys: Dict[bytes, int] = {
        bytes.fromhex(vectors["blockchain"][0]["header"]["miner"]): 0
    }
    nicks: List[bytes] = [bytes.fromhex(vectors["blockchain"][0]["header"]["miner"])]

    #Datas.
    datas: List[Data] = [
        Data.fromJSON(vectors["datas"][0]),
        Data.fromJSON(vectors["datas"][1]),
        Data.fromJSON(vectors["datas"][2])
    ]

    #Transactions.
    transactions: Transactions = Transactions()
    for data in datas:
        transactions.add(data)

    #Initial Data's Verification.
    verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])

    #MeritRemoval.
    #pylint: disable=no-member
    removal: SignedMeritRemoval = SignedMeritRemoval.fromSignedJSON(keys, vectors["removal"])

    def sendMeritRemoval() -> None:
        #Send the Datas.
        for data in datas:
            if rpc.meros.liveTransaction(data) != rpc.meros.recv():
                raise TestError("Meros didn't send us the Data.")

        #Send the initial Data's verification.
        if rpc.meros.signedElement(verif) != rpc.meros.recv():
            raise TestError("Meros didn't us the initial Data's Verification.")

        #Send and verify the MeritRemoval.
        if rpc.meros.signedElement(removal) != rpc.meros.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 1, removal.holder, True)

    def sendPacketMeritRemoval() -> None:
        #Send the Block containing the modified Merit Removal.
        block: Block = Block.fromJSON({}, vectors["blockchain"][-1]).header
        rpc.meros.blockHeader(block.header)

        #Flag of if the Block's Body synced.
        blockBodySynced: bool = False

        #Handle sync requests.
        reqHash: bytes = bytes()
        while True:
            try:
                msg: bytes = rpc.meros.recv()
            except TestError:
                if not blockBodySynced:
                    raise TestError("Node disconnected us before syncing the body.")

                #Verify the height is 2.
                #The genesis Block and the Block containing the MeritRemoval originally.
                try:
                    if rpc.call("merit", "getHeight") != 2:
                        raise Exception()
                except Exception:
                    raise TestError("Height isn't 2.")

                #Since the height is 2, raise a SuccessError.
                raise SuccessError("Meros didn't add the Block containing the same MeritRemoval again (yet with packets).")

            if MessageType(msg[0]) == MessageType.Syncing:
                rpc.meros.syncingAcknowledged()

            elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                reqHash = msg[1 : 33]
                if reqHash != block.header.hash:
                    raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

                #Send the BlockBody.
                blockBodySynced = True
                rpc.meros.blockBody([], block)

            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

    Liver(
        rpc,
        vectors["blockchain"],
        transactions,
        callbacks={
            1: sendMeritRemoval,
            2: sendPacketMeritRemoval
        }
    ).live()
    """

    raise EmptyError(a + b)
