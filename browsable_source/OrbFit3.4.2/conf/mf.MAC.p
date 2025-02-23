# Makefile options for the INTEL compiler for MAC, optimized and profiling

# Fortran compiler
FC=ifort
# Options for Fortran compiler:
FFLAGS= -cm -O -mp1 -pg -save -assume byterecl -Vaxlib -I../include 
# "ranlib" command: if it is not needed, use "RANLIB=touch"
RANLIB=ranlib -c
VPATH=../include

