! ===========MODULE close_app=============   
                                    
! MODULE CONTAINS  
! PUBLIC ROUTINES  
!            cloapp                                 
! PRIVATE ROUTINES 
!               stepcon                                                 
!               falsi                                                   
!               strclo    
! 
! OUT OF MODULE
!            npoint_set             
!            cov_avai/cov_not_av      
!            set_clost 
!
! HEADERS AND MODULES  
! close_app.o: \
!	../include/nvarx.h90 \
!	../suit/FUND_CONST.mod \
!	close_app.o \
!	tp_trace.o \
!	runge_kutta_gauss.o 


MODULE close_app

USE fund_const
USE output_control
IMPLICIT NONE
PRIVATE

! PUBLIC SUBROUTINES

PUBLIC :: cloapp

! PUBLIC DATA


! parameters with controls for close app.
DOUBLE PRECISION eprdot
! Minimum number of data points for a deep close appr
INTEGER npoint
! startup from a non close approaching state at each integration restart
LOGICAL clost
! fix mole flag... to be used only by resret2...find close app min (vsa_attx)
LOGICAL fix_mole, kill_propag, min_dist

PUBLIC eprdot,npoint,clost,fix_mole, kill_propag, min_dist

! PRIVATE COMMON DATA   

CONTAINS
!                                                                       
! ==============================================================        
! CLOAPP                                                                
! close approach control; driver for falsi                              
! vers. 1.9.2, A.Milani, August 25, 1999                                
! with decreasing stepsize near closest approach                        
! also with end of close approach flag                                  
! ==============================================================        
  SUBROUTINE cloapp(tcur,th,xa,va,nv,idc,xpla,xldir,dir,nes,cloend) 
    USE tp_trace
    USE planet_masses
! close approach control: which planet is close (0=none)                
    INTEGER idc 
! stepsize control: flag for fixed step, stepsize, direction            
    LOGICAL nes 
    DOUBLE PRECISION xldir,dir 
! current time, previous stepsize                                       
    DOUBLE PRECISION tcur,th 
! positon, velocity of asteroid, of close encounter planet              
    INTEGER nv 
    DOUBLE PRECISION xa(nv),va(nv) 
    DOUBLE PRECISION xpla(6) 
! logical flag for close approach termination                           
! to allow for storage of state transition matrix                       
    LOGICAL cloend 
! =========END INTERFACE========================================        
! stepsize tricks                                                       
    LOGICAL nesold 
    DOUBLE PRECISION xlold,tmin,dt,thfirst 
!               ,tleft                                                  
! which planet is being approached, vector difference                   
    INTEGER ic 
    DOUBLE PRECISION x(3),v(3) 
!                                                                       
    DOUBLE PRECISION vsize 
! counters for arrays of multiple minima                      
    INTEGER jc 
! loop indexes i=1,3                                                    
    INTEGER i 
! logical flags for regulae falsi being initiaited                      
    LOGICAL first 
! static memory model required                                          
    SAVE 
! ===========================================                           
    IF(clost)THEN 
       ic=0 
       clost=.false. 
    ENDIF
! close approach is not ending, in most cases                           
    cloend=.false. 
! ========================================================              
! control on close approaches                                         
    IF(ic.eq.0)THEN 
! close approach not going on; check if it is beginning                 
       IF(idc.ne.0)THEN 
! close approach detected (first step inside influence region)          
! relative position and velocity  
          x=xa(1:3)-xpla(1:3)
          v=va(1:3)-xpla(4:6)         
! planet with which close approach is taking place                      
          ic=idc 
          iplam=idc 
!           WRITE(iuncla,*)' approach to planet', iplam                 
! close approach minima counter                                         
          jc=0 
! first call to falsi                                                   
          first=.true. 
          IF(min_dist) CALL falsi(tcur,xa,va,nv,xpla,jc,first,iplam) 
! setup of fixed stepsize                                               
          nesold=nes 
          nes=.true. 
          xlold=xldir 
!  stepsize based upon angular velocity                                 
          CALL stepcon(x,v,npoint,dmin(idc),dir,dt) 
! not allowed to be longer than the one used before the close approach  
          xldir=dir*min(abs(th),abs(dt)) 
! which is stored for alter use                                         
          thfirst=th 
       ENDIF
    ELSE 
! close approach taking place                                           
!    control of inconsistences                                          
       IF(idc.ne.0)THEN 
          IF(idc.ne.ic.or.idc.gt.nmass.or.idc.lt.0)THEN 
             WRITE(*,*)' closap: this should not happen',idc,ic 
          ENDIF
! relative position and velocity                                        
          x(1:3)=xa(1:3)-xpla(1:3) 
          v(1:3)=va(1:3)-xpla(4:6) 
          first=.false. 
          IF(min_dist)CALL falsi(tcur,xa,va,nv,xpla,jc,first,iplam)
! mole fix case: check kill_propag
          IF(kill_propag)THEN
             cloend=.true. 
             xldir=xlold 
             nes=nesold 
             ic=0 
             njc=jc 
             jc=0 
             RETURN
          ENDIF 
!  stepsize based upon angular velocity                                 
          CALL stepcon(x,v,npoint,dmin(idc),dir,dt) 
! not allowed to be longer than the one used before the close approach  
          xldir=dir*min(abs(thfirst),abs(dt)) 
       ELSE 
!   close approach ended; reset flags etc.                              
          cloend=.true. 
          xldir=xlold 
          nes=nesold 
          ic=0 
          njc=jc 
          jc=0 
       ENDIF
    ENDIF
! =================================================                     
  END SUBROUTINE cloapp
! =================================================                     
! STEPCON                                                               
! numerical stepsize control based on true anomaly                      
! =================================================                     
      SUBROUTINE stepcon(x,v,npoin,disc,dir,dt) 
! input: geocentric state                                               
      DOUBLE PRECISION x(3),v(3) 
! input: min no points, size of MTP disc, direction of time             
      INTEGER npoin 
      DOUBLE PRECISION disc,dir 
! outpput: suggested stepsize                                           
      DOUBLE PRECISION dt 
! end interface                                                         
      DOUBLE PRECISION prscal,vsize 
      DOUBLE PRECISION dtheta,cosdt1,dtheta1,tmin,dtold 
      DOUBLE PRECISION x1(3),cgeo(3),jgeo 
      dtheta=pig/npoin 
      CALL prvec(x,v,cgeo) 
      jgeo=vsize(cgeo) 
      dt=prscal(x,x)*dtheta/jgeo*dir 
      CALL lincom(x,1.d0,v,dt,x1) 
      cosdt1=prscal(x,x1)/(vsize(x)*vsize(x1)) 
      dtheta1=acos(cosdt1) 
      IF(dtheta1.gt.dtheta)THEN 
         dt=(dtheta/dtheta1)*dt 
      ENDIF 
      tmin=2*disc/vsize(v) 
      dtold=tmin/npoin*dir
      IF(abs(dt).lt.1.d-5)THEN 
         WRITE(iun_log,*)'stepcon: ',dt, dtold,vsize(x),vsize(v),dtheta1,jgeo  
         dt=1.d-5
         IF(.not.min_dist)kill_propag=.true.
      ENDIF     
      END SUBROUTINE stepcon                                          
! =====================================                                 
! FALSI  regula falsi                                                   
! =====================================                                 
 SUBROUTINE falsi(t,xa,va,nv,xpla,jc,first,iplam) 
   USE output_control
   USE runge_kutta_gauss
   USE planet_masses
! INPUT                                                                 
! current position and velocity                                         
   INTEGER nv 
   DOUBLE PRECISION t,xa(nv),va(nv),xpla(6) 
! is this the beginning of an integration?                              
   LOGICAL first 
! planet being approached                                               
   INTEGER iplam 
! INPUT AND OUTPUT                                                      
! close approach counter                              
   INTEGER jc
! =====================================                                 
! fixed stepsize time interval                                          
   DOUBLE PRECISION tt1,tt2 
! data for regula falsi                                                 
   DOUBLE PRECISION r1,r2,r0,rdot1,rdot2,rdot0,t1,t2,t0 
   DOUBLE PRECISION z1,z2,z0,zdot1,zdot2,zdot0 
! functions                                                             
   DOUBLE PRECISION vsize,prscal 
! state vectors: without partials ! with partials 
   INCLUDE 'nvarx.h90' 
   DOUBLE PRECISION x(nvar2x),v(nvar2x),xt(nvar2x),vt(nvar2x),xplat(6) 
   DOUBLE PRECISION xat(nvar2x),vat(nvar2x) 
! time steps                                                            
   DOUBLE PRECISION dt,tt,di,hh 
! iterations                                                            
   INTEGER it,i 
! ======for ID========                                                
   DOUBLE PRECISION moid0 
! variables for call to compute_minima                                  
   DOUBLE PRECISION x6(6) 
! cartesian coordinates asteroid and planet at minimum                  
   DOUBLE PRECISION cmin(3,16),cplmin(3,16) 
!     SQUARED DISTANCE function                                         
   DOUBLE PRECISION d2(16) 
!     number of relative minima found                                   
   INTEGER nummin 
   INTEGER, PARAMETER :: itmax_f=50 !iterations of falsi
   DOUBLE PRECISION :: peri
!
! ====================                                                
! memory model is static                                                
   SAVE 
! default for flag stopping propagation due to collision
   kill_propag=.false.
! planetocentric position with derivatives
   x(1:nv)=xa(1:nv)
   v(1:nv)=va(1:nv)
   x(1:3)=xa(1:3)-xpla(1:3) 
   v(1:3)=va(1:3)-xpla(4:6) 
! initialisation at the beginning of each close approach                
   IF(first)THEN 
      tt1=t 
      r1=vsize(x) 
      rdot1=prscal(x,v)/r1 
      IF(nv.eq.21)THEN
! MOID at the beginning of each encounter                               
         x6(1:3)=xa(1:3) 
         x6(4:6)=va(1:3)      
         CALL compute_minima_ta(x6,xpla,iplam,cmin,cplmin,d2,nummin)
      ENDIF 
! end initialisation of close approach                                  
      RETURN 
   ENDIF
! compute r, rdot                                                       
   r2=vsize(x) 
   rdot2=prscal(x,v)/r2 
   tt2=t 
! direction of time propagation                                         
   IF(tt2.gt.tt1)THEN 
      di=1.d0 
   ELSEIF(tt2.lt.tt1)THEN 
      di=-1.d0 
   ELSE 
      WRITE(iun_log,199)tt1,tt2,x(1:3) !,v,xpla
 199  FORMAT(' falsi: zero step ',f8.2,1x,f8.2,1P,3(1x,d10.3))
      RETURN 
   ENDIF
! if inside Earth, use 2-body propagation
   IF(iplam.eq.3.and.r2.lt.4.2e-5.and.fix_mole)THEN
! let this be handled by strclo       
      CALL strclo(iplam,t,xpla,xa,va,nv,jc,r2,rdot2,         &
     &        d2,cplmin,nummin)                                         
      rdot2=0.d0 
! check for minimum distance                                            
   ELSEIF(abs(rdot2).lt.eprdot)THEN 
! already at stationary point; WARNING: is it a minimum?                
      CALL strclo(iplam,t,xpla,xa,va,nv,jc,r2,rdot2,         &
     &        d2,cplmin,nummin)                                         
      rdot2=0.d0 
   ELSEIF(rdot1*di.lt.0.d0.and.rdot2*di.gt.0.d0)THEN 
! rdot changes sign, in a way appropriate for a minimum                 
      t1=tt1 
      t2=tt2 
!        WRITE(*,*) ' r. f. begins, t,r,rdot=',t1,r1,rdot1,t2,r2,rdot2  
!        WRITE(iuncla,*) ' r. f. begins ',t1,r1,rdot1,t2,r2,rdot2       
      dt=-rdot2*(t1-t2)/(rdot1-rdot2) 
      tt=dt+t2 
      hh=tt-t 
! iterate regula falsi                                                  
      DO it=1,itmax_f 
         CALL rkg(t,xa,va,nv,hh,xat,vat,xplat) 
! planetocentric position                                               
         xt(1:3)=xat(1:3)-xplat(1:3) 
         vt(1:3)=vat(1:3)-xplat(4:6) 
         r0=vsize(xt) 
         rdot0=prscal(xt,vt)/r0 
         t0=tt 
! selection of next couple of points with opposite sign                 
         IF(abs(rdot0*dt).lt.eprdot)THEN 
!  already at stationary point; WARNING: is it a minimum? 
            CALL strclo(iplam,tt,xplat,xat,vat,nv,jc,r0,rdot0,&
     &             d2,cplmin,nummin)                                    
            GOTO 2 
         ELSEIF(rdot0*rdot1.lt.0.d0)THEN 
            r2=r0 
            rdot2=rdot0 
            t2=t0 
         ELSEIF(rdot0*rdot2.lt.0.d0)THEN 
            r1=r0 
            rdot1=rdot0 
            t1=t0 
         ENDIF
         dt=-rdot2*(t1-t2)/(rdot1-rdot2) 
         tt=dt+t2 
         hh=tt-t 
      ENDDO
! failed convergence                                                    
      CALL strclo(iplam,t0,xplat,xat,vat,nv,jc,r0,rdot0,     &
     &        d2,cplmin,nummin)                                         
      WRITE(ierrou,*)' falsi: failed convergence for ',ordnam(iplam) 
      WRITE(ierrou,*)'t1,r1,rdot1,t2,r2,rdot2,dt,tt' 
      WRITE(ierrou,111)t1,r1,rdot1,t2,r2,rdot2,dt,tt 
!        WRITE(*,*)' falsi: failed convergence for ',ordnam(iplam)      
!        WRITE(*,*)'t1,r1,rdot1,t2,r2,rdot2,dt,tt'                      
!        WRITE(*,111)t1,r1,rdot1,t2,r2,rdot2,dt,tt                      
111   format(8(1x,f16.9)) 
      numerr=numerr+1 
   ENDIF
! found zero                                                            
2  CONTINUE 
! save current state to be previous state next time                     
   tt1=tt2 
   r1=r2 
   rdot1=rdot2 
 END SUBROUTINE falsi
! ===================================================                    
! TP_FSER
!  xt,vt = geocentric coordinates and partials at time t0
!  xat,vat= geocentric cood and partials at time t0+dt of perigee
! =================================================== 
  SUBROUTINE  tp_fser(nv,t0,xt,vt,iplam,xpla,xat,vat,dt)
    USE ever_pitkin
    USE planet_masses
    INTEGER, INTENT(IN) :: nv,iplam
    DOUBLE PRECISION, INTENT(IN) :: t0,xt(nv),vt(nv)
    DOUBLE PRECISION, INTENT(OUT) :: dt, xpla(6),xat(nv),vat(nv)
! ===================== 
    DOUBLE PRECISION, DIMENSION(6,6) :: dxvdxtvt,dxvdx0,dxdx0
    DOUBLE PRECISION, DIMENSION(3) :: vlenz
    DOUBLE PRECISION :: vel2,gei2,gei,ecc,peri,sig0,alpha,psi,r0,conv_contr
!  ang era definito scalare....
    DOUBLE PRECISION, DIMENSION(3) :: ang

! functions                                                             
    DOUBLE PRECISION vsize,prscal 
    r0=vsize(xt)
    vel2=prscal(vt,vt)
    call prvec(xt,vt,ang)
    gei2=prscal(ang,ang)
    gei=sqrt(gei2)
    IF(gei.eq.0.d0)THEN 
       WRITE(*,*) ' tp_fser: zero angular momentum ',xt,vt,t0 
    ENDIF
    call prvec(vt,ang,vlenz)                    ! Lenz vector
    vlenz=vlenz/gm(iplam)-xt(1:3)/r0
    ecc=vsize(vlenz)
    peri=gei2/(gm(iplam)*(1.d0+ecc))
    sig0=prscal(xt(1:3),vt(1:3))
    alpha=vel2-2*gm(iplam)/r0 ! 2* energy
!    WRITE(*,*) 'before ', ecc,peri,gei,alpha
    conv_contr=10*epsilon(1.d0)
    CALL solve_peri(r0,sig0,peri,gm(iplam),alpha,psi,dt,conv_contr)
    IF(nv.eq.3)THEN
       CALL fser_propag(xt,vt,0.d0,dt,gm(iplam),xat(1:3),vat(1:3))
    ELSE
       CALL vawrxv(xt,vt,dxdx0,nv)
       CALL fser_propag_der(xt,vt,0.d0,dt,gm(iplam),xat(1:3),vat(1:3),dxvdxtvt)
       dxvdx0=MATMUL(dxvdxtvt,dxdx0)
       CALL varunw(dxvdx0,xat,vat,nv)
       r0=vsize(xat)
       vel2=prscal(vat,vat)
       call prvec(xat,vat,ang)
       gei2=prscal(ang,ang)
       gei=sqrt(gei2)
       IF(gei.eq.0.d0)THEN 
          WRITE(*,*) ' falsi: zero angular momentum ',xat,vat,t0+dt 
       ENDIF
       call prvec(vat,ang,vlenz)                    ! Lenz vector
       vlenz=vlenz/gm(iplam)-xat(1:3)/r0
       ecc=vsize(vlenz)
       peri=gei2/(gm(iplam)*(1.d0+ecc))
       alpha=vel2-2*gm(iplam)/r0 ! 2* energy
!       WRITE(*,*) 'after ', ecc,peri,gei,alpha,gm(iplam)
    ENDIF
    CALL earcar(t0+dt,xpla,1)
END SUBROUTINE tp_fser
! ===================================================                   
! STRCLO                                                                
! store close approach                                                  
! ===================================================                   
SUBROUTINE strclo(iplam0,tcur,xpla,xa,va,nv,jc,r,rdot,            &
     &             d2,cplmin,nummin) 
  USE tp_trace
  USE planet_masses
! input                                                                 
! planet number
  INTEGER, INTENT(IN) :: iplam0
! time current, distance, radial velocity (should be small)             
  DOUBLE PRECISION,INTENT(IN) :: tcur,r,rdot 
! cartesian coordinates of planet at local MOID                           
  DOUBLE PRECISION, INTENT(IN) :: cplmin(3,16) 
! SQUARED DISTANCE function at local MOIDs
  DOUBLE PRECISION, INTENT(IN):: d2(16) 
! number of relative minima (local MOID) found
  INTEGER, INTENT(IN) :: nummin 
!  planet position and velocity                                         
  DOUBLE PRECISION, INTENT(IN):: xpla(6) 
! heliocentrci position and velocity                                    
!  with partial derivatives if nv=21, without if nv=3                   
  INTEGER, INTENT(IN) :: nv 
  DOUBLE PRECISION, INTENT(IN) :: xa(nv),va(nv) 
!  input/output : close approach minima conter                          
  INTEGER, INTENT(INOUT) :: jc 
! =========end interface==================== 
! state vectors: without partials ! with partials 
  INCLUDE 'nvarx.h90' 
  DOUBLE PRECISION x(nvar2x),v(nvar2x)
  DOUBLE PRECISION xat(nvar2x),vat(nvar2x) 
  CHARACTER*30 :: planam 
  DOUBLE PRECISION vl,vsize,dt,r2,rdot2,tcur2, xpla2(6)
  INTEGER i 
  INTEGER lpla,lench 
! calendar date variables                                               
  INTEGER iyear,imonth,iday 
  DOUBLE PRECISION hour 
  CHARACTER*16 date 
! multiple minima analysis                                              
  DOUBLE PRECISION cosa,angle,prscal,angmin 
  INTEGER j
  iplam=iplam0
  planam=ordnam(iplam)
! control to avoid computation of moid in strange orbits 
  IF(nv.eq.21)THEN
! store current local moid (just before encounter)                      
     IF(nummin.le.0)THEN
        moid0=-0.9999d0
        angmoid=0.d0
     ELSE   
        moid0=sqrt(d2(1)) 
        angmoid=4.d2 
        angmin=4.d2
        DO j=1,nummin 
           cosa=prscal(cplmin(1,j),xpla)/(vsize(cplmin(1,j))*vsize(xpla)) 
           angle=acos(cosa) 
           IF(angle.lt.angx*radeg)THEN
              IF(angle.lt.angmin*radeg)THEN 
                 moid0=sqrt(d2(j)) 
                 angmoid=angle*degrad
                 angmin=angle*degrad 
              ENDIF
           ENDIF
        ENDDO
     ENDIF
  ENDIF
! planetocentric position with derivatives
  x(1:nv)=xa(1:nv)
  v(1:nv)=va(1:nv)
  x(1:3)=xa(1:3)-xpla(1:3) 
  v(1:3)=va(1:3)-xpla(4:6) 
! handle near miss
   IF(iplam.eq.3.and.r.lt.reau*20)THEN
! if inside Earth, use 2-body propagation
      CALL tp_fser(nv,tcur,x,v,iplam,xpla2,xat,vat,dt)
! xat,vat are planetocentric a periplanet
      r2=vsize(xat(1:3)) 
! minimum forced by 2-body solution, store
      rdot2=prscal(xat(1:3),vat(1:3))/r2
      tcur2=tcur+dt
! only for resret, if passing inside Earth, returns are not real
      IF(fix_mole.and.r.lt.reau) kill_propag=.true.
! the following setting doesn't work as expected
!     IF(fix_mole.and.r.lt.reau/3.d0) kill_propag=.true. 
   ELSE
      xat(1:nv)=x(1:nv)
      vat(1:nv)=v(1:nv)
      r2=r
      rdot2=rdot
      tcur2=tcur
      xpla2=xpla
   ENDIF    
! store close approach point                                            
  jc=jc+1 
  IF(jc.gt.njcx)THEN 
     WRITE(*,*)' strclo: jc>njcx ',jc,njcx,' at ', tcur
     WRITE(ierrou,*)' strclo: jc>njcx ',jc,njcx,' at ', tcur
     numerr=numerr+1
     IF(fix_mole)THEN
        kill_propag=.true.
     ENDIF
     jc=jc-1 
     RETURN
  ENDIF
  tcla(jc)=tcur2 
  rmin(jc)=r2 
  DO i=1,3 
     xcla(i,jc)=xat(i)
     vcla(i,jc)=vat(i) 
     xplaj(i,jc)=xpla(i) 
     xplaj(i+3,jc)=xpla(3+i) 
  ENDDO
  lpla=lench(planam) 
  numcla=numcla+1 
  call mjddat(tcur2,iday,imonth,iyear,hour) 
  IF(verb_clo.gt.9)THEN
     write(date,'(i4,a1,i2.2,a1,i2.2,f6.5)') iyear,'/',imonth,'/',iday,hour/24d0
     WRITE(*,97)planam(1:lpla),date,tcur2,r2 
97   FORMAT(' Close approach to ',a,' on ',a16,f12.5,' MJD at ',f10.8,' AU.')
  ENDIF
  IF(nv.eq.3)THEN 
! nothing to do
  ELSEIF(nv.eq.21)THEN 
! store partials at close approach time                                 
     DO i=4,21 
        xcla(i,jc)=xat(i) 
        vcla(i,jc)=vat(i) 
     ENDDO
! planet velocity is needed [to define reference system] 
     xplaj(1:6,jc)=xpla(1:6) 
  ELSE 
     write(*,*)' strclo: nv=',nv 
     STOP 
  ENDIF
END SUBROUTINE strclo
  
END MODULE close_app  

! routines not belonging to the module
! ==============================================================  
! NPOINT_SET
! ==============================================================  
SUBROUTINE npoint_set(npmult)
  USE close_app
  IMPLICIT NONE
  INTEGER, INTENT(IN) :: npmult
  INTEGER npoint0
  DOUBLE PRECISION eprdot0
  LOGICAL :: init = .true.
  IF(init)THEN
     npoint0=npoint
     eprdot0=eprdot
     init=.false.
  ENDIF
  npoint=npoint0*npmult
  IF(npmult.eq.1)THEN
     eprdot=eprdot0
  ELSE
     eprdot=1d-3*eprdot0
  ENDIF
END SUBROUTINE npoint_set
! ==============================================================  
! SET_CLOST
SUBROUTINE set_clost(clostin)
  USE close_app
  IMPLICIT NONE
  LOGICAL clostin
  clost=clostin
END SUBROUTINE set_clost
! ==============================================================        
! COV_AVAI/COV_NOT_AV                                                   
! routines to manipulate the covariance common used                     
! for online target plane analysys                                      
! =============================================================         
SUBROUTINE cov_avai(unc,coo,coord) 
  USE tp_trace
  USE orbit_elements
  IMPLICIT NONE 
! INPUT: covariance matrix, elements, coordinates
  TYPE(orb_uncert), INTENT(IN) :: unc
  DOUBLE PRECISION, INTENT(IN) :: coord(6)
  CHARACTER*3, INTENT(IN) :: coo
! HIDDEN OUTPUT: covariance matrix and flag of availability             
  unc_store=unc 
  coord_store=coord
  coo_store=coo
  covava=.true. 
END SUBROUTINE cov_avai
SUBROUTINE cov_not_av 
  USE tp_trace
  IMPLICIT NONE 
! HIDDEN OUTPUT: flag of availability                                   
  covava=.false. 
END SUBROUTINE cov_not_av


