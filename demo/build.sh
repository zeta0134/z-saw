#!/bin/bash

ca65 -g -o demo.o demo.s
ca65 -g -o zsaw.o ../zsaw.s
ld65 -o zsaw.nes --dbgfile zsaw.dbg -C nrom.cfg zsaw.o demo.o