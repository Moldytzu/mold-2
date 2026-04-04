data = []

de_scris = "Salut lume!"

for c in de_scris:
    data.append(ord(c))

with open("input.rom", "wb") as fp:
    fp.write(bytearray(data))
