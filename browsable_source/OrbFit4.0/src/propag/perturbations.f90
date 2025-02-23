! \headmod{PERTURBATIONS}{Tommei, Cical\'o, Milani, Latorre}{22/10/2008}
MODULE perturbations
  USE fund_const
!  USE fund_const_bc
  USE output_control
!  USE fund_var
!  USE read_ephem_bc
  USE planet_masses
  IMPLICIT NONE 
  PRIVATE
! \comments
! PERTURBATIONS: perturbation routines used by Debris Software        
!                                                                       
!  sunplan: Simplified computations for lunisolar perturbations 
  PUBLIC :: sunmoon_pert, radp

! shared data
! options for non gravitational perturbations
  INTEGER, PUBLIC :: irad
! options for sun-moon perturbations
  INTEGER, PUBLIC :: itide ! tide
  INTEGER, PUBLIC :: ipla  ! 0=no, 2=Sun+Moon
CONTAINS


! \bighorline
  SUBROUTINE sunmoon_pert(x,ef,dplan,dlove,pk2cur,partials) 
! \comments
! This routine computes Solar and Lunar perturbations on satellite 
! in geocentric position \\ $\vec{x}=(x_1,x_2,x_3).$ 
! INPUT \\
! partials: if true partial derivatives computation \\
! x: geocentric satellite position \\
! pk2cur: current value of Mercury Love number $k_2$ \\
! ef: geocentric positions of Sun and Moon 
! (in the order gived before) \\
! 
! \bigskip
!         OUTPUT \\
! dlove: partial derivative of perturbative acceleration w.r.t. $k_2$ \\
! dplan(1:3,1) : perturbative acceleration due to planetary and tidal effects\\
! dplan(1:3,2:4): partial derivatives of perturbative acceleration w.r.t. 
! initial conditions $x_1,x_2,x_3$ \\
!
! \interface           
! computation of derivatives
    LOGICAL, INTENT(IN) :: partials 
! spacecraft position (mercurycentric)
    REAL(KIND=dkind), DIMENSION(3), INTENT(IN) :: x 
! current value of Mercury Love number $k_2$                         
    REAL(KIND=dkind), INTENT(IN) :: pk2cur 
! position of Sun and Moon 
    REAL(KIND=dkind), DIMENSION(3,2), INTENT(IN) :: ef
! perturbative acceleration (and partials): planetary and tidal effects 
    REAL(KIND=dkind), DIMENSION(3,4), INTENT(OUT) :: dplan 
! partial derivatives of the acceleration w.r.t. to the Love number $k_2$  
    REAL(KIND=dkind), DIMENSION(3), INTENT(OUT) :: dlove
! \endint
! indexes                                                               
    INTEGER :: i,j,j1, jj 
! vector temporaries
    REAL(KIND=dkind), DIMENSION(3) :: xb,d
! scalar temporaries                                                    
    REAL(KIND=dkind) :: dsb2,dsb3,rb2,rb3,md3,md5 
!  functions                                                            
    REAL(KIND=dkind) :: prscal 
! planetary masses
    REAL(KIND=dkind), DIMENSION(nplax) :: gmp
! auxiliary variables for modelling the degree 2 tidal effects          
    REAL(KIND=dkind) :: rs2,rs4,rs,rs3,tc,sp,aux3,aux5
    REAL(KIND=dkind), DIMENSION(3) :: td,tcd
! radius of the planet from 
    REAL(KIND=dkind) :: rpla

! Earth radius
    rpla=reau
! Masses of Sun and Moon
    gmp(1)=gms
    gmp(2)=gmoon
! set output to zero                                                    
    dplan=0.d0 
! iteration on disturbing bodies (Sun and Moon)                          
    DO i=1,2
! compute perturbative acceleration due to Sun and Moon            
       DO j=1,3 
          xb(j)=ef(j,i) 
          d(j)=xb(j)-x(j) 
       ENDDO
       rb2=prscal(xb,xb) 
       dsb2=prscal(d,d) 
       dsb3=dsb2*dsqrt(dsb2) 
       rb3=rb2*dsqrt(rb2)
! Perturbative accelerations of Sun and Moon:
       dplan(1:3,1)=dplan(1:3,1)+gmp(i)*(d(1:3)/dsb3-xb(1:3)/rb3) 
! degree 2 (proportional to $k_2$) tidal effect due to the Solar (i=1) 
! gravity field generating Love potential $U_{Love}$ and corresponding 
! disturbing force $\nabla U_{Love}$
       IF(itide.EQ.1)then 
          rs2=prscal(x,x) 
          rs4=rs2**2 
          rs=dsqrt(rs2) 
          rs3=rs*rs2                             
          tc=0.5d0*gmp(i)*(rpla**5)/(rb3*rs4) 
          sp=prscal(xb,x)
! partial derivatives of $\nabla U_{Love}$ w.r.t. $k_2$ (linear dependence) 
          DO j=1,3 
             dlove(j)=tc*((3.d0-15.d0*sp*sp/(rb2*rs2))*x(j)/rs+             &
                  &                  6.d0*sp*xb(j)/(rb2*rs))
! complete perturbative acceleration $\vec{a}_p$ containing planetary 
! perturbations and Love tidal perturbation due to the Sun
             dplan(j,1)=dplan(j,1)+dlove(j)*pk2cur 
          ENDDO
       ENDIF
! if partials compute partial derivatives w.r.t. satellite initial 
! conditions $x_1,x_2,x_3.$ \\
! First compute partials of ``third body'' perturbation term     
       IF(partials)THEN 
          md3=gmp(i)/dsb3 
          md5=3.d0*md3/dsb2 
          DO j=1,3 
!             j1=4*j 
!             dplan(j1)=dplan(j1)+md5*(d(j)**2)-md3 
             dplan(j,j+1)=dplan(j,j+1)+md5*(d(j)**2)-md3 
          ENDDO
!          dplan(5)=dplan(5)+md5*d(1)*d(2) 
!          dplan(6)=dplan(6)+md5*d(1)*d(3) 
!          dplan(9)=dplan(9)+md5*d(2)*d(3) 
          dplan(2,2)=dplan(2,2)+md5*d(1)*d(2) 
          dplan(3,2)=dplan(3,2)+md5*d(1)*d(3) 
          dplan(3,3)=dplan(3,3)+md5*d(2)*d(3) 
! compute partial derivatives of Love tidal perturbation 
! $\nabla U_{Love}$ due to the Sun w.r.t. satellite initial conditions 
! $x_1,x_2,x_3$ and sum with previous partial derivatives terms. \\
! Note that these partials are tested with Matlab7 symbolic toolbox
          IF((i.EQ.1).AND.(itide.EQ.1))THEN        
             aux3=sp/(rb2*rs3) 
             aux5=sp*sp/(rb2*rs3*rs2) 
             DO j=1,3 
 !               j1=4*j 
                tcd(j)=-4.d0*tc*x(j)/rs2 
                td(j)=3.d0*x(j)/rs-15.d0*sp*aux3*x(j)+6.d0*sp*ef(j,i)/(rb2*rs) 
                dplan(j,j+1)=dplan(j,j+1)+tcd(j)*pk2cur*(3.d0*x(j)/rs- &
                     &   15.d0*sp*aux3*x(j)+                         &
                     &   15.d0*sp*ef(j,i)/(rb2*rs))+                 &
                     &   tc*pk2cur*(3.d0/rs-3.d0*x(j)*x(j)/rs3-      &
                     &   15.d0*aux3*sp+45.d0*aux5*x(j)*x(j)+         &
                     &   6.d0*ef(j,i)**2/(rb2*rs))                
             ENDDO
             dplan(2,2)=dplan(2,2)+pk2cur*(tcd(2)*td(1)+            &
                  & tc*(-3.d0*x(1)*x(2)/rs3-                        &
                  &  aux3*(30.d0*x(1)*ef(2,i)+6.d0*x(2)*ef(1,i))+   &
                  &  45.d0*aux5*x(1)*x(2)+6.d0*ef(1,i)*             &
                  &  ef(2,i)/(rb2*rs)))                           
             dplan(3,2)=dplan(3,2)+pk2cur*(tcd(3)*td(1)+tc*(-3.d0*x(1)*x(3)/&
                  &  rs3-aux3*(30.d0*x(1)*ef(3,i)+                  &
                  &  6.d0*x(3)*ef(1,i))+45.d0*aux5*x(1)*x(3)+       &
                  &  6.d0*ef(3,i)*ef(1,i)/(rb2*rs)))              
             dplan(3,3)=dplan(3,3)+pk2cur*(tcd(3)*td(2)+tc*(-3.d0*x(2)*x(3)/&
                  &  rs3-aux3*(30.d0*x(2)*ef(3,i)+                  &
                  &  6.d0*x(3)*ef(2,i))+                            &
                  &  45.d0*aux5*x(2)*x(3)+6.d0*ef(2,i)*             &
                  &  ef(3,i)/(rb2*rs)))                           
          ENDIF
       ENDIF
    ENDDO
! symmetry of the partials: 
! $\partial a_p(i)/\partial x_j =\partial a_p(j)/\partial x_i \; 
! \forall i\neq j$
    IF(partials)THEN
       dplan(1,3)=dplan(2,2) 
       dplan(1,4)=dplan(3,2) 
       dplan(2,4)=dplan(3,3) 
    ENDIF
    
  END SUBROUTINE sunmoon_pert

! \bighorline
! *** {\bf radp} ***                                                           
! \comments
! \begin{verbatim}
! This is a modified version of the direct solar radiation              
! pressure soubroutine for the purpose of the Mercury                   
! orbiter mission. At the moment it contains only the spherical         
! model of the satellite, but accounts correctly for the                
! geometric shadowing of the solar disk by the Mercury's                
! surface.                                                              
!                                                                       
! written by D Vokrouhlicky (Nov 1999)                                  
! (queries to vokrouhl mbox.cesnet.cz)                                  
! \end{verbatim}

     SUBROUTINE radp(x,s,accrad) 
! x(6) = mercuro-centric state vector of the satellite\par              
! s(3) = mercuro-centric position of the Sun\par                        
! accrad(3) = mercuro-centric acceleration of the satellite             
!               due to the radiation pressure\par                       
! accradp(3) = partial derivative of accrad(3) wrt the                  
!                reflectivity coefficient                               
! \interface
!  INPUT                                                                
      REAL(KIND=dkind), INTENT (IN) :: x(6),s(3)
!  OUTPUT                                                               
      REAL(KIND=dkind), INTENT (OUT) :: accrad(3)
! \endint
! local variables                                                       
      REAL(KIND=dkind) :: rsun,rsun2,rsat,scal,ciome,siome,cs1,cs2,css 
      REAL(KIND=dkind) :: au2,dsrpma,asum,crad,cbeta,beta,omega 
      REAL(KIND=dkind) :: commb,dor,facdi,ratrr,brac,dsrpmap 

! functions                                                             
      REAL(KIND=dkind) :: prscal 
! radius of Sun, of planet
      REAL(KIND=dkind) :: radsun, rpla,scc
! loop integers                                                         
      INTEGER :: i 
!                                                                       
!      INCLUDE 'parpar.h' 
!      INCLUDE 'compar.h' 
!      INCLUDE 'trig.h' 
!     INCLUDE 'comcon.h' 
      INCLUDE 'jplhdr.h90' 
!      INCLUDE 'satellite.h' 
!      INCLUDE 'planet.h' 

! initialization
! Radius of Sun in AU                                                        
      radsun=r_sun/aukm
!      rpla=r_planet
      rpla=reau
      accrad=0.d0 
      rsun2=prscal(s,s) 
      rsun=dsqrt(rsun2) 
      rsat=dsqrt(prscal(x,x)) 
      scal=prscal(x,s) 
      ciome=scal/rsat/rsun 
      siome=dsqrt(1.d0-ciome*ciome) 
      ratrr=rsat/rsun 
      brac=1.d0+ratrr*(ratrr-2.d0*ciome) 
! get radiation force-factor                                            
!      au2=aucm*aucm 
      au2=aukm**2 
! WARNING
      asum=pig*1d-8
! ===============
!      asum=pig*ragsfe*ragsfe/pmas 
!      dsrpma=asum*crad*scc*au2/rsun2/brac
      scc=1.37d16*aukm**2 
      dsrpma=asum*scc*au2/rsun2/brac
!      dsrpmap=asum*scc*au2/rsun2/brac 
! test the shadow occurence and its penumbra/umbra phase                
      cs2=-((radsun-rpla)*rpla/rsun/rsat)-                              &
     &     dsqrt(1.d0-(((radsun-rpla)/rsun)**2))*                       &
     &     dsqrt(1.d0-((rpla/rsat)**2))                                 
! satellite in full shadow:                                             
      IF(ciome.LE.cs2)THEN 
!       write(93,111)(t/86400.)                                         
! 111   format(f7.3)                                                    
       RETURN 
      ENDIF 
      cs1=((radsun+rpla)*rpla/rsun/rsat)-                               &
     &     dsqrt(1.d0-(((radsun+rpla)/rsun)**2))*                       &
     &     dsqrt(1.d0-((rpla/rsat)**2))                                 
      IF(ciome.GE.cs1)THEN 
! satellite fully illuminated by the Sun                                
       facdi=1.d0 
      ELSE 
! satellite in penumbra                                                 
       cbeta=rpla/rsat 
       css=(cbeta*rpla/rsun)-dsqrt(1.d0-((rpla/rsun)**2))*              &
     &     dsqrt(1.d0-(cbeta**2))                                       
       omega=dacos(ciome) 
       beta=dacos(cbeta) 
       commb=dcos(omega-beta) 
       IF(ciome.GE.css)THEN 
! - more than a half of the solar disk seen from the satellite          
        dor=(rsun*commb-rpla)/radsun 
        facdi=1.d0-(dacos(dor)-dor*dsqrt(1.d0-dor*dor))/pig 
       ELSE 
! - less than a half of the solar disk seen from the satellite          
        dor=(rpla-rsun*commb)/radsun 
        facdi=(dacos(dor)-dor*dsqrt(1.d0-dor*dor))/pig 
       ENDIF 
      ENDIF 
! Spherical satellite assumed                                           
      IF(irad.EQ.1)THEN 
       DO i=1,3 
          accrad(i)=-dsrpma*(s(i)-x(i))*facdi/rsun/dsqrt(brac) 
       ENDDO 
      ENDIF 
! Cylindrical satellite with antenna                                    
! (see Milani etal. ...)                                                
      IF(irad.EQ.2)THEN 
! TO BE ADDED LATER FROM NONGRAV.F IF NECESSARY                         
       WRITE(*,*)' model of the satellite not ready' 
       WRITE(*,*)' yet; in prad ',irad 
       STOP 
      ENDIF 
! out-of-range check                                                    
      IF(irad.GT.2)THEN 
       WRITE(*,*)' Parameter irad out-of-range; in prad ',irad 
       STOP 
      ENDIF 
    END SUBROUTINE radp


END MODULE perturbations

