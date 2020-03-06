include MainDatabase

proc reorganize(
    lastCommonBlock: Hash[256],
    tail: BlockHeader
): Future[void] {.forceCheck: [
    ValueError,
    DataMissing
].} =
    raise newException(ValueError, "Chain reorganizations aren't supported.")
