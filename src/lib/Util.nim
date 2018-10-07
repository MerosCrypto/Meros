#Left-pads a string, with a certain value, until the string is a certain length.
func pad*(
    data: string,
    len: int,
    prefix: string | char = "0"
): string {.raises: [].} =
    result = data
    while result.len < len:
        result = prefix & result
