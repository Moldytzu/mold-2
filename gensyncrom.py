#!/bin/python

# Data format:
#
#   7 6 5 4 3 2 1 0
#   R V H VIS x x x x

bit_reset = 1<<7 # end, reset counters
bit_v = 1<<6 # vsync
bit_h = 1<<5 # hsync
bit_visible_areab = 1<<4
bit_visible_area = 1<<3


# ROM size to fill
romsize = 32*1024

# Vertical timing measured in lines
num_v_visible = 480
num_v_frontporch = 10
num_v_sync = 2
num_v_backporch = 33

# Horizontal timing measured in 16-pixel blocks
num_h_visible = 40
num_h_skip_visible = 8
num_h_frontporch = 1
num_h_sync = 6
num_h_backporch = 3

# sync polarity
vsync_polarity_pos = False
hsync_polarity_pos = False


# base value - no image, no sync, not end
basevalue = bit_reset + bit_visible_areab
if not vsync_polarity_pos:
    basevalue += bit_v
if not hsync_polarity_pos:
    basevalue += bit_h
#line = ([(porchvalue - bit_visible_areab) | bit_visible_area] * (num_h_skip_visible//2) + [porchvalue + bit_visible_area] * num_h_visible + [(porchvalue - bit_visible_areab) | bit_visible_area] * (num_h_skip_visible//2))
 

def gen_line(vsync, vizibil=False, in_range_vizibil=False):
    porchvalue = basevalue ^ (bit_v if vsync else 0)
    if vizibil:
        line = ([porchvalue] * (num_h_skip_visible//2))
        line += (([(porchvalue - bit_visible_areab) | bit_visible_area] * (num_h_visible-num_h_skip_visible)))
        line += ([porchvalue] * (num_h_skip_visible//2))
        
    elif in_range_vizibil:
        line = ([porchvalue + bit_visible_area] * num_h_visible)
    else:
        line = ([porchvalue] * num_h_visible)
    line.extend([porchvalue] * num_h_frontporch)
    line.extend([porchvalue ^ bit_h] * num_h_sync)
    line.extend([porchvalue] * num_h_backporch)
    return line

skip_lines = (480-120*3)//2
skip_lines = 0
data = []
for line in range(num_v_visible):
    data.extend(gen_line(False, (line >= skip_lines and line < num_v_visible - skip_lines), True))
data.extend(num_v_frontporch * gen_line(False))
data.extend(num_v_sync * gen_line(True))
data.extend(num_v_backporch * gen_line(False))
data[-1] ^= bit_reset

print(len(data))
assert len(data) == 26250

data.extend([basevalue ^ bit_reset] * (romsize - len(data)))


with open("sync.rom", "wb") as fp:
    fp.write(bytearray(data))

