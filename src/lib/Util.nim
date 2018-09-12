#Pads a string with a prefix to be a certain length.
proc pad*(data: string, len: int, prefix: string = "0"): string {.raises: [].} =
    result = data
    while result.len < len:
        result = prefix & result
