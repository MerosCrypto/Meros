#Types.
from typing import Dict, List, Tuple, Any

#Element classes.
from python_tests.Classes.Consensus.Element import Element, SignedElement
from python_tests.Classes.Consensus.Verification import Verification, SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import MeritRemoval, PartiallySignedMeritRemoval, SignedMeritRemoval
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

    #Calculate a Block's aggregate
    def getAggregate(
        self,
        records: List[
            Tuple[blspy.PublicKey, int, int]
        ]
    ) -> bytes:
        signatures: List[blspy.Signature] = []

        for record in records:
            holder: bytes = record[0].serialize()
            start: int = record[1]
            end: int = record[2]
            if end == -1:
                end = len(self.holders[holder])
            else:
                end += 1

            for e in range(start, end):
                signatures.append(SignedElement.fromElement(self.holders[holder][e]).blsSignature)

        result: bytes = blspy.Signature.aggregate(signatures).serialize()
        return result

    #Calculate a holder's merkle
    def getMerkle(
        self,
        holderArg: blspy.PublicKey,
        start: int,
        end: int = -1
    ) -> bytes:
        holder: bytes = holderArg.serialize()
        merkle: List[bytes] = []

        end += 1
        if end == 0:
            end = len(self.holders[holder])

        for e in range(start, end):
            elem: Element = self.holders[holder][e]
            if isinstance(elem, Verification):
                merkle.append(
                    blake2b(
                        elem.prefix + Verification.serialize(Verification.fromElement(elem)),
                        digest_size = 48
                    ).digest()
                )
            elif isinstance(elem, MeritRemoval):
                if len(merkle) != 0:
                    raise Exception("Creating a merkle with a MeritRemoval despite the merkle already having elements.")

                merkle.append(
                    blake2b(
                        elem.prefix + MeritRemoval.serialize(MeritRemoval.fromElement(elem)),
                        digest_size = 48
                    ).digest()
                )

                if e != end - 1:
                    raise Exception("Creating a merkle with a MeritRemoval despite the merkle having more elements after this.")
            else:
                raise Exception("MeritHolder has an unsupported Element type: " + type(elem).__name__)

        if len(merkle) == 0:
            return b'\0' * 48

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
                if hasattr(elem, "toSignedJSON"):
                    result[holder.hex().upper()].append(SignedElement.fromElement(elem).toSignedJSON())
                else:
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
                if "signed" in elem:
                    if elem["descendant"] == "Verification":
                        result.add(SignedVerification.fromJSON(elem))
                    elif elem["descendant"] == "MeritRemoval":
                        if elem["partial"]:
                            result.add(PartiallySignedMeritRemoval.fromJSON(elem))
                        else:
                            result.add(SignedMeritRemoval.fromJSON(elem))
                    else:
                        raise Exception("JSON has an unsupported Element type: " + elem["descendant"])
                else:
                    if elem["descendant"] == "Verification":
                        result.add(Verification.fromJSON(elem))
                    elif elem["descendant"] == "MeritRemoval":
                        result.add(MeritRemoval.fromJSON(elem))
                    else:
                        raise Exception("JSON has an unsupported Element type: " + elem["descendant"])
        return result
