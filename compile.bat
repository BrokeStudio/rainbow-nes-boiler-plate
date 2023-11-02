@echo off

:: sources
bin\ca65 -g --debug-info -I src -o obj/main.o src/main.s -DCHR_CHIPS=2

:: libraries

:: link
bin\ld65 -o "roms/rainbow-nes-boiler-plate.nes" -C nes.cfg --dbgfile "roms/rainbow-nes-boiler-plate.dbg" obj/main.o
