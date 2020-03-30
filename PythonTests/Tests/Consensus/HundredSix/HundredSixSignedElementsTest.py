#https://github.com/MerosCrypto/Meros/issues/106. Specifically tests signed elements (except MeritRemovals).

#Types.
from typing import List

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, Signature

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Signed Element classes.
from PythonTests.Classes.Consensus.Element import SignedElement
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from PythonTests.Classes.Consensus.DataDifficulty import SignedDataDifficulty

#RPC class.
from PythonTests.Meros.RPC import RPC

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Sleep standard function.
from time import sleep

#Blake2b standard function.
from hashlib import blake2b

def HundredSixSignedElementsTest(
    rpc: RPC
) -> None:
    #Blockchain. Solely used to get the genesis Block hash.
    blockchain: Blockchain = Blockchain()

    #BLS Key.
    blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
    sig: Signature = blsPrivKey.sign(bytes())

    #Create a Data.
    #This is required so the Verification isn't terminated early for having an unknown hash.
    data: bytes = bytes.fromhex(rpc.call("personal", "data", ["AA"]))

    #Create a signed Verification, SendDifficulty, and DataDifficulty.
    elements: List[SignedElement] = [
        SignedVerification(data, 1, sig),
        SignedSendDifficulty(0, 0, 1, sig),
        SignedDataDifficulty(0, 0, 1, sig)
    ]

    for elem in elements:
        #Handshake with the node.
        rpc.meros.liveConnect(blockchain.blocks[0].header.hash)

        #Send the Element.
        rpc.meros.signedElement(elem)

        #Sleep for a bit.
        sleep(0.2)

        #Verify the node didn't crash.
        try:
            if rpc.call("merit", "getHeight") != 1:
                raise Exception()
        except Exception:
            raise TestError("Node crashed after being sent a malformed Element.")
