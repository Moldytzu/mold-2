data = []

for i in range(256):
    data.append(i%20)

with open("input.rom", "wb") as fp:
    fp.write(bytearray(data))
