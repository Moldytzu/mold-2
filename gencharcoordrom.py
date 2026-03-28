bit_x0 = 1<<0 
bit_x1 = 1<<1 
bit_x2 = 1<<2 
bit_y0 = 1<<3
bit_y1 = 1<<4
bit_y2 = 1<<5
bit_enb = 1<<6

# ROM size to fill
romsize = 32*1024

width = 160
height = 120

vertical_spacing = 2

char_size = 8

charcoordrom = []
charnumrom = []

character = 0
for y in range(0, height):
    for i in range(3):
        for x in range(0, width):
            byte = bit_enb
            char_y = y%10
            char_x = x%8
            if char_y < 8:
                byte -= bit_enb
                byte += char_x
                byte += char_y * 8
            charcoordrom.append(byte)
            # charnumrom should increase by 1 every 8 pixels
            charnumrom.append(x// char_size + (y//(char_size+vertical_spacing)) * (width//char_size))

with open("charcoordrom.rom", "wb") as fp:
    fp.write(bytearray(charcoordrom))

with open("charnumrom.rom", "wb") as fp:
    fp.write(bytearray(charnumrom))