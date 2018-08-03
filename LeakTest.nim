import BN

proc main() =
    var i: int = 0

    while true:
        discard newBN()
        discard newBN(i)
        inc(i)

main()
