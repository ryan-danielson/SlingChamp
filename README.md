# SlingChamp
An x86 assembly game where slinging is all the rage. Collect as many letters as possible without hooking yourself!

![slingchamp](https://user-images.githubusercontent.com/23747085/120880310-a3d30980-c57e-11eb-8fcf-9b7638e75d32.png)

## Compile Instructions
To compile using NASM under Ubuntu 18.04.5:
i
        $ nasm -f elf32 slingchamp.asm
        $ ld slingchamp.o -m elf_i386 -o slingchamp --entry main -dynamic-linker /lib/ld-linux.so.2 -lc
        $ ./slingchamp

You can also link using gcc instead. Must force 32bit as that is what it's written in.

## Controls
* <kbd>a</kbd><kbd>s</kbd><kbd>w</kbd><kbd>d</kbd>: Orient player around a platform (left, down, up, right)
* <kbd>j</kbd><kbd>k</kbd><kbd>i</kbd><kbd>l</kbd>: Shoot hook in givent direction  (left, down, up, right)
* Double-tap hook direction for super-speed!

## Issues
As this is a terminal-based game with constant refreshing, some terminals perform better than others. Have had best luck in GNOME terminal, iTerm; poor performance in URXVT.

