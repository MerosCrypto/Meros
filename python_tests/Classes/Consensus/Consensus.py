#Types.
from typing import Dict, List, Any

#Element classes.
from python_tests.Classes.Consensus.Element import Element, SignedElement
from python_tests.Classes.Consensus.Verification import Verification
from python_tests.Classes.Consensus.SpamFilter import SpamFilter

#BLS lib.
import blspy

#Blake2b standard function.
from hashlib import blake2b

#Consensus class.
class Consensus:
    #Constructor.
    def __init__(
        self,
        sendDiff: bytes,
        dataDiff: bytes
    ) -> None:
        self.sendFilter = SpamFilter(sendDiff)
        self.dataFilter = SpamFilter(dataDiff)
        self.holders: Dict[bytes, List[Element]] = {}

    #Add an Element.
    def add(
        self,
        elem: Element
    ) -> None:
        if not elem.holder in self.holders:
            self.holders[elem.holder] = []
        self.holders[elem.holder].append(elem)

    #Get a holder's aggregate
    def getAggregate(
        self,
        holderArg: blspy.PublicKey,
        start: int,
        end: int = 0
    ) -> bytes:
        holder: bytes = holderArg.serialize()
        signatures: List[blspy.Signature] = []

        end += 1
        if end == 1:
            end = len(self.holders[holder])

        for e in range(start, end):
            signatures.append(SignedElement.fromElement(self.holders[holder][e]).blsSignature)

        result: bytes = blspy.Signature.aggregate(signatures).serialize()
        return result

    #Get a holder's merkle
    def getMerkle(
        self,
        holderArg: blspy.PublicKey,
        start: int,
        end: int = 0
    ) -> bytes:
        holder: bytes = holderArg.serialize()
        merkle: List[bytes] = []

        end += 1
        if end == 1:
            end = len(self.holders[holder])

        for e in range(start, end):
            prefix: bytes = bytes()
            if isinstance(self.holders[holder][e], Verification):
                prefix = b'\0'

            merkle.append(
                blake2b(
                    prefix + self.holders[holder][e].serialize(),
                    digest_size = 48
                ).digest()
            )

        while len(merkle) != 1:
            if len(merkle) % 2 == 1:
                merkle.append(merkle[-1])

            for m in range(0, len(merkle), 2):
                merkle[m // 2] = blake2b(
                    merkle[m] + merkle[m + 1],
                    digest_size = 48
                ).digest()

            merkle = merkle[: len(merkle) // 2]

        return merkle[0]

    #Consensus -> JSON.
    def toJSON(
        self
    ) -> Dict[str, List[Dict[str, Any]]]:
        result: Dict[str, List[Dict[str, Any]]] = {}
        for holder in self.holders:
            result[holder.hex().upper()] = []
            for elem in self.holders[holder]:
                result[holder.hex().upper()].append(elem.toJSON())
        return result

    #JSON -> Consensus.
    @staticmethod
    def fromJSON(
        sendDiff: bytes,
        dataDiff: bytes,
        json: Dict[str, List[Dict[str, Any]]]
    ) -> Any:
        result = Consensus(
            sendDiff,
            dataDiff
        )
        for mh in json:
            for elem in json[mh]:
                if elem["descendant"] == "verification":
                    result.add(Verification.fromJSON(elem))
        return result
