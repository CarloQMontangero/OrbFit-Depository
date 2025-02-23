
! *************************************
!        S  O  L  V  P  O  L  Y        
! *************************************
! find the real roots of a polynomial with degree poldeg
! with real coefficients
 SUBROUTINE solve_poly_QP(poldg,coef,roots,nroots,hzflag,multfl)
   USE output_control
   IMPLICIT NONE 
   INTEGER, PARAMETER :: qkind=kind(1.q0) !for quadruple precision
   INTEGER, INTENT(IN) :: poldg ! polynomial degree
   REAL(KIND=qkind), INTENT(IN) :: coef(0:poldg) ! z^i coeff. (i=0,poldg)   
   REAL(KIND=qkind), INTENT(OUT) :: roots(poldg) !real roots
   INTEGER, INTENT(OUT) :: nroots ! number of real roots
   LOGICAL,INTENT(INOUT) :: hzflag ! hzflag = .true.  OK!
                                   ! hzflag = .false. abs(root)>10^5
   LOGICAL,INTENT(INOUT) :: multfl ! multfl = .true.  OK!
                                   ! multfl = .false. 0 has multiplicity > 4
! =============== end interface =======================================
   REAL(KIND=qkind), PARAMETER :: epsil=epsilon(1.q0)*10.d0
   COMPLEX(KIND=qkind) :: zr1(poldg) 
   REAL(KIND=qkind) :: radius(poldg) 
   COMPLEX(KIND=qkind) :: poly(0:poldg)
   REAL(KIND=qkind) :: epsm,big,small,rad(poldg),a1(poldg+1), &
        & a2(poldg+1),rim,rre 
   INTEGER :: nit,j,i,pdeg 
   REAL(KIND=qkind) ,DIMENSION(poldg) :: zeros 
   INTEGER :: numzerosol,numzerocoe
   LOGICAL err(poldg+1) 
! =====================================================================

! initialization
   numzerosol = 0
   numzerocoe = 0
   roots(1:poldg) = 0.q0
   pdeg = poldg

! for polzeros
   epsm=2.q0**(-53) 
   big=2.q0**1023 
   small=2.q0**(-1022) 

   poly(0:pdeg)=coef(0:pdeg) 
   
! *************************
! look for zero solutions   
! *************************
   IF(abs(poly(0)).le.epsil) THEN
      WRITE(ierrou,*)'CONSTANT TERM is CLOSE to ZERO!',poly(0)
      numerr=numerr+1
      numzerosol = 1
      pdeg = pdeg-1
      IF(abs(poly(1)).le.epsil) THEN
         WRITE(ierrou,*)'FIRST DEGREE TERM is CLOSE to ZERO!',poly(1)
         numzerosol = 2
         pdeg = pdeg-1
         IF(abs(poly(2)).le.epsil) THEN
            WRITE(ierrou,*)'SECOND DEGREE TERM is CLOSE to ZERO!',poly(2)
            numzerosol = 3
            pdeg = pdeg-1
            IF(abs(poly(3)).le.epsil) THEN
               WRITE(ierrou,*)'THIRD DEGREE TERM is CLOSE to ZERO!',poly(3)
               numzerosol = 4
               pdeg = pdeg-1
               IF(abs(poly(4)).le.epsil) THEN
                  WRITE(ierrou,*)'solvpoly: ERROR! &
                       & zero solution has multiplicity > 4'
                  multfl = .false.
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF
   
! ************************************************
! check the decrease of the degree up to poldg-4  
! ************************************************
   IF(abs(poly(poldg)).le.epsil) THEN
      WRITE(ierrou,*)poldg,'DEGREE TERM is CLOSE to ZERO!',poly(poldg)
      numerr=numerr+1
      pdeg = pdeg-1
      numzerocoe = 1
      IF(abs(poly(poldg-1)).le.epsil) THEN
         WRITE(ierrou,*)poldg-1,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-1)
         pdeg = pdeg-1
         numzerocoe = 2
         IF(abs(poly(poldg-2)).le.epsil) THEN
            WRITE(ierrou,*)poldg-2,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-2)
            pdeg = pdeg-1
            numzerocoe = 3
            IF(abs(poly(poldg-3)).le.epsil) THEN
               WRITE(ierrou,*)poldg-3,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-3)
               pdeg = pdeg-1
               numzerocoe = 4

            IF(abs(poly(poldg-4)).le.epsil) THEN
               WRITE(ierrou,*)poldg-4,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-4)
               pdeg = pdeg-1
               numzerocoe = 5

            IF(abs(poly(poldg-5)).le.epsil) THEN
               WRITE(ierrou,*)poldg-5,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-5)
               pdeg = pdeg-1
               numzerocoe = 6

            IF(abs(poly(poldg-6)).le.epsil) THEN
               WRITE(ierrou,*)poldg-6,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-6)
               pdeg = pdeg-1
               numzerocoe = 7

            IF(abs(poly(poldg-7)).le.epsil) THEN
               WRITE(ierrou,*)poldg-7,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-7)
               pdeg = pdeg-1
               numzerocoe = 8

            IF(abs(poly(poldg-8)).le.epsil) THEN
               WRITE(ierrou,*)poldg-8,'DEGREE TERM is CLOSE to ZERO!',poly(poldg-8)
               pdeg = pdeg-1
               numzerocoe = 9



!               write(*,*)'max=',maxval(abs(poly)),'min=',minval(abs(poly))
!               write(*,*)'epsil=',epsil, &
!               & 'ratio=',maxval(abs(poly))/minval(abs(poly))

! ***************************************************
! TEMPORARY FIX: should include arbitrary decrease in degree...
               IF(abs(poly(poldg-9)).le.epsil) THEN 
                  nroots=0
                  RETURN
               ENDIF
! ***************************************************
            ENDIF
            ENDIF
            ENDIF
            ENDIF
            ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF

   
! *********************************************************************   
   CALL polzeros_QP(pdeg,poly(numzerosol:poldg-numzerocoe),epsm,big,small, &
        & 50,zr1,rad,err,nit,a1,a2) 
! *********************************************************************   
   
   nroots=0 
   
   zeros(1:poldg) = 0.q0
101 FORMAT(i20,15(2x,f20.8))
102 FORMAT(f20.8,15(2x,f20.8))

   DO 11 j = 1,pdeg

!      WRITE(*,*)'ROOT(',j,')=',zr1(j)
!      rim=IMAG(zr1(j))                                                 
      rim=AIMAG(zr1(j)) 
!      IF(ABS(rim).LT.10.d-4) THEN                                      
      IF(ABS(rim).LT.rad(j)) THEN 
!      IF(ABS(rim).LT.2.d0*rad(j)) THEN 

!      write(*,*),rad(j)
!      IF(ABS(rim).LT.40.d5*rad(j)) THEN 

         rre=REAL(zr1(j)) 
! uncomment if you want only positive real roots                    
      IF(rre.LT.0.q0) GOTO 11                                      
         nroots=nroots+1 
         roots(nroots)=rre 
         radius(nroots)=rad(j) ! error estimate            

! ***************************
! check if some root is big
! ***************************
         IF(abs(roots(nroots)).gt.1.q8) THEN
            write(ierrou,*)'large value for a root',roots(nroots)
            numerr=numerr+1
            hzflag=.false.
!            write(*,*)'hzflag',hzflag
         ENDIF

      END IF
11 END DO
   
!   write(*,*)'roots:',roots(1:nroots)

   IF(numzerosol.gt.0) THEN
      DO i = 1,numzerosol
         nroots=nroots+1 
         roots(nroots)=0.q0 
         radius(nroots)=0.q0 ! dummy
!         write(*,*)'roots(',nroots,')=',roots(nroots)
      ENDDO
   ENDIF
   
 END SUBROUTINE solve_poly_QP
