#!/bin/python

bit_x0 = 1 << 0
bit_x1 = 1 << 1
bit_x2 = 1 << 2
bit_y0 = 1 << 3
bit_y1 = 1 << 4
bit_y2 = 1 << 5
bit_enb = 1 << 6

romsize = 64 * 1024

width = 160
height = 360

vertical_spacing = 2
char_size = 8
y_repeat = 3

chars_per_row = width // char_size
logical_row_height = char_size + vertical_spacing
num_char_rows = height // (logical_row_height * y_repeat)

charcoordrom = []
charnumrom = []

# Generate screen pixel-by-pixel, BUT with correct character stepping
for pixel_counter in range(romsize):
    screen_pixel = pixel_counter % (width * height)

    x = screen_pixel % width
    y = screen_pixel // width

    # Apply vertical scaling
    logical_y = y // y_repeat

    # Character position
    char_x = x // char_size
    char_y = logical_y // logical_row_height

    # Pixel inside character block
    pixel_in_char_x = x % char_size
    pixel_in_char_y = logical_y % logical_row_height

    # ---- CHAR COORD ROM ----
    if pixel_in_char_y >= char_size:
        byte = bit_enb
    else:
        byte = pixel_in_char_x | (pixel_in_char_y << 3)
        byte |= bit_enb

    charcoordrom.append(byte)

    # ---- FIXED CHARNUM ROM ----
    # Force character index to be stable per character cell
    char_index = char_x + char_y * chars_per_row

    #char_index = char_index % 2
    #if char_index == 0:
    #    char_index = ord('A')
    #else:
    #    char_index = ord('B')

    charnumrom.append(char_index)

# Pad to ROM size
while len(charcoordrom) < romsize:
    charcoordrom.append(0)

while len(charnumrom) < romsize:
    charnumrom.append(0)

with open("charcoordrom.rom", "wb") as fp:
    fp.write(bytearray(charcoordrom))

with open("charnumrom.rom", "wb") as fp:
    fp.write(bytearray(charnumrom))