@echo off

:: sources
bin\ca65 -g --debug-info -I src -o obj/main.o src/main.s -DCHR_CHIPS=1

:: libraries

:: link
bin\ld65 -o "roms/mapper-nes-boiler-plate.nes" -C nes.cfg --dbgfile "roms/mapper-nes-boiler-plate.dbg" obj/main.o
