"""
#Tests proper reversal of pending Elements when Meros handles a MeritRemoval.

#Types.
from typing import Dict, List, IO, Any

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#Consensus classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def PendingActionsTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/PendingActions.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    file.close()

    #Blockchain.
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )

    #SignedVerifications.
    verifs: List[SignedVerification] = []
    for verif in vectors["verifications"]:
        verifs.append(SignedVerification.fromJSON(verif))
    #Removal.
    removal: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal"])

    #Datas.
    datas: List[Data] = []
    for data in vectors["datas"]:
        datas.append(Data.fromJSON(data))

    #Send every Data/Verification.
    def sendDatasAndVerifications() -> None:
        #Send the Datas.
        for data in datas:
            if rpc.meros.transaction(data) != rpc.meros.recv():
                raise TestError("Unexpected message sent.")

        #Send the Verifications.
        for verif in verifs:
            if rpc.meros.signedElement(verif) != rpc.meros.recv():
                raise TestError("Unexpected message sent.")

        #Verify every Data has 100 Merit.
        for data in datas:
            if rpc.call("consensus", "getStatus", [data.txHash.hex()])["merit"] != 100:
                raise TestError("Meros didn't verify Transactions with received Verifications.")

    #Cause a MeritRemoval.
    def causeMeritRemoval() -> None:
        #Send every Data/;Verification.
        sendDatasAndVerifications()

        #Send the problem Verification and verify the MeritRemoval.
        rpc.meros.signedElement(removal.se2)
        if rpc.meros.recv() != MessageType.SignedMeritRemoval.toByte() + removal.signedSerialize():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal, True)

        #Verify every Data has 0 Merit.
        for data in datas:
            if rpc.call("consensus", "getStatus", [data.txHash.hex()])["merit"] != 0:
                raise TestError("Meros didn't revert pending actions of a malicious MeritHolder.")

    #Send a MeritRemoval.
    def sendMeritRemoval() -> None:
        #Send every Data/;Verification.
        sendDatasAndVerifications()

        #Send and verify the MeritRemoval.
        if rpc.meros.signedElement(removal) != rpc.meros.recv():
            raise TestError("Meros didn't send us the Merit Removal.")
        verifyMeritRemoval(rpc, 1, 100, removal, True)

        #Verify every Data has 0 Merit.
        for data in datas:
            if rpc.call("consensus", "getStatus", [data.txHash.hex()])["merit"] != 0:
                raise TestError("Meros didn't revert pending actions of a malicious MeritHolder.")

    #Check the Data's finalized with the proper amount of Merit and update the MeritRemoval.
    def check() -> None:
        #Verify the Datas have the Merit they should.
        for data in datas:
            if rpc.call("consensus", "getStatus", [data.txHash.hex()])["merit"] != 0:
                raise TestError("Meros didn't finalize with the reverted pending actions of a malicious MeritHolder.")

        #Update the MeritRemoval's nonce.
        removal.nonce = 6

        #Verify the MeritRemoval is now accessible with a nonce of 6.
        verifyMeritRemoval(rpc, 7, 0, removal, False)

    #Create and execute a Liver to cause a MeritRemoval.
    Liver(
        rpc,
        blockchain,
        callbacks={
            1: causeMeritRemoval,
            7: check
        }
    ).live()

    #Reset the MeritRemoval nonce.
    removal.nonce = 0

    #Create and execute a Liver to handle a MeritRemoval.
    Liver(
        rpc,
        blockchain,
        callbacks={
            1: sendMeritRemoval,
            7: check
        }
    ).live()

    #Synced records with MeritRemovals do not include pending actions to revert.
"""
