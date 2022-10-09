# Boot Sector Raycasting

This is a 3D raycasting engine that can fit entirely inside the boot sector of a floppy disk. As a result, the program is exactly 512 bytes large, uses no floating point arthmetic, and, in a strange sort of way, is its own tiny operating system (technically it takes the place of a boot loader, but this sounds cooler). It makes use of the same technique emplyed by the first Wolfenstein 3D game, but has half a kilobyte to work with for all machine code and data memory.

Here's a look at the machine code that makes it tick. This contains the map data, a sin function approximation, all of the redering logic, and input handling:

![alt text](https://github.com/Chemist02/Boot-Sector-Raycasting/blob/main/images/data.png)

And here's the program running on an Intel 386 VM. It doesn't look great, but I can assure you even this took many hours to accomplish. 3D without floating point is hard, even more so with only 512 bytes for everything! Of course it doesn't help that I'm not particularly good at x86.

![alt text](https://github.com/Chemist02/Boot-Sector-Raycasting/blob/main/images/raycast.png)

## How It Works
I won't go into raycasting here, since that's explained all over the place (e.g. https://en.wikipedia.org/wiki/Wolfenstein_3D#Development). Instead, I'll go over some of the techniques that were used to force this thing to work against its will (this is an angry piece of software). First, the elephant in the room: how to do something like this without floating point, especially considering that trignometry is pretty much non-negotiable for this method. In a nutshell, any time fractional values were needed, I just stored the value times 128. This allowed for seven binary decimal places! Using a factor of 128 is especially convenient since we can divide this factor away and round down using bitwise right shifting instead of the div instruction, which saves a LOT of instruction memory (div instructions require a lot of mov instructions to set up and extract the result, whereas shl is only 2 bytes). 

As for how sin is calculated, the obvious choice (without using floating point) is to use a lookup table of sin values times 128. Unfortunately, this also uses a tremendous about of memory, so I had to eliminate it as an option pretty quickly. The comprimise was to use 6 different linear approximations for sin(x) times 128 that work well in different intervals of x, and then create a lookup table of these approximations. This is usually sufficient to get within 1-2% of the actual value of 128sin(x), which was good enough to make the sloppy looking image you see above! Is it jank? 100%. But does it work well enough for this silly exercise? I'm gonna go ahead and possibly yes! 

The last thing I'll mention is how the map is encoded. To save space it's a 16x16 cell map stored as 16 16-bit integers, with bit i of number j in the array representing the
wall status of map cell (i, j) (i.e. a wall is present at (i, j) iff the corresponding bit location is a 1).

## Running The Program
You can assemble the program youself using flat assembler (http://flatassembler.net/), or just just use the binary provided in the repo! I'd recommend running it using the qemu (https://www.qemu.org/) i386 emulator, but given that this is tecnically a boot loader, you can 100% put this into the boot sector of a USB, floppy disk, or hard drive and boot to it! Oh, and you can use the left and right arrow keys to looks around!
