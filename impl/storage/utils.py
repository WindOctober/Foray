ADDR_SIZE = 20
SLOT_SIZE = 32


def slot_num2bytes(slot_num: str) -> bytes:
    return int(slot_num).to_bytes(length=SLOT_SIZE, byteorder="big")


def str2bytes(data: str) -> bytes:
    data = data[2:] if data.startswith("0x") else data
    return bytes.fromhex(data)

def int2address(data: int) -> str:
    h = hex(data)
    h = h[2:] if h.startswith("0x") else h
    return "0x" + h.zfill(ADDR_SIZE * 2)

def bytes2address(data: bytes) -> str:
    h = hex(int.from_bytes(data, "big"))
    h = h[2:] if h.startswith("0x") else h
    return "0x" + h.zfill(ADDR_SIZE * 2)

def pad_string(s: str, length: int, c: str = '0', left: bool = True) -> str:
    if len(s) >= length:
        return s
    if left:
        return c * (length - len(s)) + s
    else:
        return s + c * (length - len(s))

def pad_bytes(s: bytes, length: int, c: int = 0, left: bool = True) -> bytes:
    if len(s) >= length:
        return s
    vector = bytes([c] * (length - len(s)))
    if left:
        return vector + s
    else:
        return s + vector

def offset_bytes32(bytes32: bytes, v: int) -> bytes:
    result = bytearray(bytes32)
    a = 256
    for i in range(31, -1, -1):
        current = result[i]
        current += v
        result[i] = current % a
        v = current // a
    return bytes(result)
