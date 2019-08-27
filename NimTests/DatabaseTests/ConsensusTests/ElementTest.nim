#Element Test.

#Hash lib.
import ../../../src/lib/Hash

#Consensus lib.
import ../../../src/Database/Consensus/Element

proc test*() =
    #Create a Verification, casted down to an Element.
    var elem: Element = newVerificationObj(Hash[384]())

    #Run it through case.
    case elem:
        of Verification as verif:
            discard verif.hash
        else:
            assert(false)


    echo "Finished the Database/Consensus/Element Test."