include ../make.flags
include modules.flags

#all: two_states.o  
all:  ../lib/libangmom.a fitobs_kepint.x 
#all: ../lib/libangmom.a orbprelim_AM.x fitobs_kepint.x test_det.x 
#all: link_radar_obs.x
#all: test_pq_derpar.x
#all: test_det.x test_poly_prod.x test_poly_sum.x
#all: angular_momentum_AR.x

MATHLIB= solve_poly_QP.o  pol_zeros_QP.o

#OP_SUBS= poly_op.o poly_eval.o orbprelim_util_QP.o pq_derpar.o \
#         detcomp_QP.o orbprelim_newton_raphson.o kepint.o

OP_SUBS= poly_op.o poly_eval.o fourier_transform.o \
	 solve_system.o pq_derpar.o orbprelim_newton_raphson.o kepint.o

COPYING=two_states.o stacop.o
#obs_convert.o

FIDENT=identsub.o

FINOUT=fitobs_interfaces.o finopt.o  

FITOBS= $(COPYING) fitobs_kepint.o  $(FIDENT) $(FINOUT)

# library
../lib/libangmom.a: $(MATHLIB) $(OP_SUBS)
	ar r ../lib/libangmom.a $(MATHLIB) $(OP_SUBS)
	$(RANLIB) ../lib/libangmom.a

LIBDEPS= ../lib/libangmom.a  ../lib/libprop.a ../lib/libmoid.a ../lib/libgauss.a ../lib/libsuit.a 

fitobs_kepint.x: $(FITOBS) $(LIBDEPS)
	$(FC) $(FFLAGS) $(FITOBS) $(LIBDEPS) -o fitobs_kepint.x  


link_radar_obs.x: link_radar_obs.o determinants.o $(LIBDEPS)
	$(FC) $(FFLAGS) link_radar_obs.o determinants.o $(MATHLIB) $(LIBDEPS) \
        -o link_radar_obs.x

test_pq_derpar.x: test_pq_derpar.o pq_derpar.o
	$(FC) $(FFLAGS) test_pq_derpar.o pq_derpar.o -o test_pq_derpar.x

test_poly_prod.x: test_poly_prod.o poly_product.o
	$(FC) $(FFLAGS) test_poly_prod.o poly_product.o -o test_poly_prod.x

test_poly_sum.x: test_poly_sum.o poly_sum.o
	$(FC) $(FFLAGS) test_poly_sum.o poly_sum.o -o test_poly_sum.x

test_det.x: test_det.o $(OP_SUBS) $(LIBDEPS)
	$(FC) $(FFLAGS) test_det.o $(OP_SUBS) $(LIBDEPS) -o test_det.x

angular_momentum_AR.x: angular_momentum_AR.o $(LIBDEPS)
	$(FC) $(FFLAGS) angular_momentum_AR.o $(LIBDEPS) -o \
	angular_momentum_AR.x

orbprelim_AM.x: orbprelim_AM.o $(LIBDEPS)
	$(FC) $(FFLAGS) orbprelim_AM.o $(LIBDEPS) -o \
	orbprelim_AM.x

#limiting_curve.x: limiting_curve.o sample_sing.o mathlib.a
#	$(FC) $(FFLAGS) limiting_curve.o sample_sing.o mathlib.a \
#	-o limiting_curve.x

depend:
	../../bin/mkdep90 -I../include -L ../suit -L ../propag *.f *.f90 *.h *.h90 > make.dep
	../../bin/mkmoddep -f ../.compiler ../suit ../propag > modules.flags

clean:
	-(rm -f *~ *.x *.o \#*\# *.mod)