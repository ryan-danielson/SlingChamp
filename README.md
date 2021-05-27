# SlingChamp
An assembly game where slinging is all the rage.

# Compile Instructions
To compile using NASM under Ubuntu 18.04.5:
* nasm -f elf32 slingchamp.asm
* ld slingchamp.o -m elf_i386 -o slingchamp --entry main -dynamic-linker /lib/ld-linux.so.2 -lc
* ./slingchamp

You can also link using gcc instead. Must force 32bit as that is what it's written in.

# Controls
* <kbd>a</kbd><kbd>s</kbd><kbd>w</kbd><kbd>d</kbd>: Orient player around a platform (left, down, up, right)
* <kbd>j</kbd><kbd>k</kbd><kbd>i</kbd><kbd>l</kbd>: Shoot hook in givent direction  (left, down, up, right)

# Instructions
Collect as many letters as possible without hooking yourself!
