! ========MODULE tp_trace================================  
!
! CONTAINS         
! LIST OF PUBLIC ENTITIES:
!
!  SUBROUTINES 
!             str_clan
!             wri_tppoint
!             rea_tppoint
!             wri_clan [private]
!             marg2    [private] ???
!             rea_clorec
!                      CONTAINS
!                               rea_clan [private]
!  DATA TYPE 
!             tp_point
!             mtp_point
! 
! =========================================================
! DEP.                                
! tp_trace.o: \
!	../include/nvarx.h90 \
!	../suit/fund_const.mod \
!	../suit/orbit_elements.mod \
!	../suit/output_control.mod \
!	../suit/planet_masses.mod 
! ==========================================================


MODULE tp_trace
USE output_control
USE orbit_elements
IMPLICIT NONE

PRIVATE

! INTEGER, PARAMETER :: ncol= 27

! deltasigma, max value of sigma
DOUBLE PRECISION deltasig, smax
! index range of multiple solution 
INTEGER m1,m2
INTEGER nmul
! output on TP/MTP?
LOGICAL, PUBLIC :: tpplane ! if true, convert to tp; if false, mtp

TYPE tp_point ! trace on TP (extended to 6d) of a close approach
     DOUBLE PRECISION  :: tcla         ! Time of close approach 
     DOUBLE PRECISION, DIMENSION(6) :: xytp ! position and velocity on the asymptote
     DOUBLE PRECISION ::  b, d, v, bsd, theta, phi, txi, tze ! auxiliary variables 
     TYPE(orbit_elem) :: opik ! Opik style orbit elements
     TYPE(orb_uncert) :: unc_opik ! normal and covariance matrix 
     DOUBLE PRECISION                      :: stretch      ! Stretching
     DOUBLE PRECISION                      :: width        ! Semiwidth
     DOUBLE PRECISION                      :: alpha        ! Angle between stretching and zeta 
                                                           ! axis
     DOUBLE PRECISION                      :: moid         ! Local MOID at the beginning of
                                                           ! close approach
     DOUBLE PRECISION                      :: angmoid      ! Angle between Earth positions at the 
                                                           ! beginning and at the end of close
                                                           ! approach
     DOUBLE PRECISION                      :: stretch_lov  ! Stretching LOV
     DOUBLE PRECISION                      :: alpha_lov    ! Angle between stretching LOV and 
                                                           ! zeta axis
     DOUBLE PRECISION                      :: sigma        ! VA's value of sigma
     DOUBLE PRECISION                      :: minposs      ! Minimun possible distance
     DOUBLE PRECISION                      :: moid_gf      ! MOID with gravitational focusing
     DOUBLE PRECISION                      :: dd2_ds       ! Derivative of square distance
                                                           ! rispect to sigma
     DOUBLE PRECISION                      :: rindex       ! real VA index
     LOGICAL                               :: tp_conv      ! true if converted to target plane,
                                                           ! false if MTP
     LOGICAL                               :: cov_tp       ! if false only
     INTEGER                               :: iplam        ! planet index
END TYPE tp_point


TYPE mtp_point ! trace on MTP (extended to 3d) of a close approach

     DOUBLE PRECISION                      :: tcla         ! Time of close approach 
     DOUBLE PRECISION                      :: rcla         ! Distance of close approach
     DOUBLE PRECISION                      :: rdotcla      ! Control on the distance
     DOUBLE PRECISION, DIMENSION(3)        :: xcla         ! VA's geocentric position
     DOUBLE PRECISION, DIMENSION(3)        :: vcla         ! VA's geocentric velocity
     DOUBLE PRECISION, DIMENSION(3)        :: tp_coord     ! Coordinates on 3-d MTP x,z,V
     DOUBLE PRECISION                      :: stretch      ! Stretching
     DOUBLE PRECISION                      :: width        ! Semiwidth
     DOUBLE PRECISION                      :: alpha        ! Angle between stretching and zeta 
                                                           ! axis
     DOUBLE PRECISION                      :: moid         ! Local MOID at the beginning of
                                                           ! close approach
     DOUBLE PRECISION                      :: angmoid      ! Angle between Earth positions at the 
                                                           ! beginning and at the end of close
                                                           ! approach
     DOUBLE PRECISION                      :: stretch_lov  ! Stretching LOV
     DOUBLE PRECISION                      :: alpha_lov    ! Angle between stretching LOV and 
                                                           ! zeta axis
     DOUBLE PRECISION                      :: dvdsigma     ! Module of derivative of velocity
                                                           ! rispect to sigma
     DOUBLE PRECISION                      :: svv          ! Square root of velocity covariance
     DOUBLE PRECISION                      :: cxv          ! Correlation between xi and velocity
     DOUBLE PRECISION                      :: czv          ! Correlation between zeta and velocity
     DOUBLE PRECISION                      :: dd2_ds       ! Derivative of square distance
                                                           ! rispect to sigma
     DOUBLE PRECISION                      :: sigma        ! VA's value of sigma
     DOUBLE PRECISION                      :: minposs      ! Minimun possible distance
     DOUBLE PRECISION                      :: moid_gf      ! MOID with gravitational focusing

     DOUBLE PRECISION                      :: rindex       ! real VA index
     
     LOGICAL                               :: tp_conv      ! true if converted to target plane,
                                                           ! false if MTP
     LOGICAL                               :: cov_tp       ! if false only tcla,rcla,rdotcla,
                                                           ! xcla, vcla are available
                                        ! note: tp_coord could be computed, but it is not
                                        ! in the present strclan3 
END TYPE mtp_point

! LIST OF PUBLIC ENTITIES
! Derived TYPEs
PUBLIC :: mtp_point, tp_point
! SUBROUTINEs
PUBLIC :: str_clan, rea_clorec, rea_clorectp!, fclan2
! PARAMETERs
PUBLIC :: deltasig, smax,m1,m2,nmul


! common data: former covariance.h
! DOUBLE PRECISION gc_store(6,6) ! covariance matrix, to be used by strclan
TYPE(orb_uncert), PUBLIC :: unc_store
DOUBLE PRECISION, PUBLIC :: coord_store(6)
CHARACTER*3, PUBLIC :: coo_store
LOGICAL, PUBLIC :: covava ! availability flag

! common data: former close_app_data
! storage space for multiple minima/multiple target plane crossing
INTEGER, PARAMETER, PUBLIC :: njcx=50
INTEGER, PUBLIC :: njc
! planet approached previously
INTEGER, PUBLIC :: ipla0
! planetary coordinates 
DOUBLE PRECISION, PUBLIC :: xplaj(6,njcx)
! currently (last) approached planet, selected minimum 
INTEGER, PUBLIC :: iplam,jcsel
! LOCAL MOID at beginnign of encounter, angle of planetary position w.r. to MOID point
DOUBLE PRECISION, PUBLIC :: moid0,angmoid
! control on angular distance from MOID point
INTEGER, PARAMETER, PUBLIC :: angx=30
! close approach time, relative position and velocity, with 
! partial derivatives with respect to cartesian coord, min. distance
DOUBLE PRECISION, PUBLIC :: tcla(njcx),xcla(21,njcx),vcla(21,njcx),rmin(njcx)
! partials of TP coords w.r. to elements
DOUBLE PRECISION, PUBLIC :: dtpde(2,6,njcx),dtpdet(6,3,njcx)
! new style common data, using tp_point and mtp_point
TYPE(mtp_point), DIMENSION(njcx), PUBLIC :: mtp_store
TYPE(tp_point),  DIMENSION(njcx), PUBLIC :: tp_store

CONTAINS

  SUBROUTINE str_clan(dx1dx0,dx0de) 
    USE planet_masses
    USE orbit_elements
    IMPLICIT NONE 
! ============INPUT========================                             
    DOUBLE PRECISION, INTENT(IN) :: dx1dx0(6,6) ! accumulated state transition matrix 
    DOUBLE PRECISION, INTENT(IN) :: dx0de(6,6) ! derivatives of init.cartesian wrt elements
! ========HIDDEN INPUT======================                            
! target plane coordinates and derivatives, moid                        
! covariance matrix                                                     
! =========HIDDEN OUTPUT====================                            
! in the .clo file                                                      
! csi, zeta, s,w,alpha                                                  
    DOUBLE PRECISION csi, zeta, stretch, width, alpha 
! via common                                                            
! basis adapted to MTP                                                  
! output from mtprot                                                    
! =========END INTERFACE===============                                 
! partial derivatives                                                   
    INCLUDE 'nvarx.h90' 
    DOUBLE PRECISION dxdx1(6,6),dxde(6,6),dxdx0(6,6),y2(nvarx) 
    INTEGER nv 
! basis adapted to MTP                                                  
    INTEGER jc 
    DOUBLE PRECISION v2(3) 
! minimum distance                                                      
    DOUBLE PRECISION r,rdot,vsize,prscal
! angle alpha                                                           
    DOUBLE PRECISION cosa,sina 
! weak direction                                                        
    DOUBLE PRECISION wdir(6),sdir
! planet names                                                          
    CHARACTER*30 planam 
    INTEGER lpla,lench 
! calendar date variables                                               
     INTEGER iyear,imonth,iday 
     DOUBLE PRECISION hour 
     CHARACTER*16 date 
! mtp normal                                                            
    DOUBLE PRECISION tpno(3),vc0,v3(3,3),vt3(3,3)
! loop indexes                                                          
    INTEGER i 
! for MTP -> TP conversion
    TYPE(orbit_elem) :: opik, mtpcar, tpcar
    DOUBLE PRECISION :: del(6,6),del1(6,6),del2(6,6),dee(6,6)
    DOUBLE PRECISION :: dtpcarde(3,6)
    DOUBLE PRECISION :: xpl(3), vpl(3), vv(3), xx(3), dz, xop(3)
    DOUBLE PRECISION :: r1(3,3), r2(3,3), rr(3,3), rop(3,3), ropt(3,3), rrt(3,3)
    DOUBLE PRECISION :: eigval(2), axes(2,2), fv1(2),fv2(2), sig(2), wtp(2)
    DOUBLE PRECISION :: tpc(3),tpr,cxv,czv,svv,wtpv,wtpr,wtpal
    TYPE(tp_point) :: tp
    INTEGER fail_flag1, fail_flag2,ierr
! ===================================================================== 
! derivative are required: select first minimum always                  
    IF(njc.eq.0)THEN 
! close approach ended, but closest approach not recorded; initial close
!       WRITE(*,*)' initial close app.? iplam=',iplam                   
       RETURN 
    ELSEIF(njc.gt.1)THEN 
       WRITE(*,*)' multiple minima, njc=',njc,tcla(1),tcla(njc),iplam 
    ENDIF
! if not, do everything for each minimum                                
    DO 1 jc=1,njc 
!         WRITE(*,*) ' str_clan: covava ', covava
       planam=ordnam(iplam) 
       lpla=lench(planam) 
       call mjddat(tcla(jc),iday,imonth,iyear,hour) 
       write(date,'(i4,a1,i2.2,a1,i2.2,f6.5)') iyear,'/',imonth,'/',iday,hour/24d0     
       IF(tpplane)THEN
! use TP with OPiK elements
         mtpcar=undefined_orbit_elem
         mtpcar%coo='CAR'
         mtpcar%coord(1:3)=xcla(1:3,jc)
         mtpcar%coord(4:6)=vcla(1:3,jc)
         mtpcar%center=iplam
         mtpcar%t=tcla(jc)
! Opik elements          
         IF(.not.covava)THEN
            tpcar=tpcar_mtpcar(mtpcar,fail_flag1,tp%bsd)
            tp%opik=opik_tpcar(tpcar,fail_flag2)
         ELSE
! partials are always available if we are here                          
            nv =21 
! First partial derivatives: rewrap vector into 6x6 matrix              
            DO i=1,nv 
               y2(i)=xcla(i,jc) 
               y2(i+nv)=vcla(i,jc) 
            ENDDO 
            CALL varwra(y2,dxdx1,nv*2,nv) 
            tpcar=tpcar_mtpcar(mtpcar,fail_flag1,tp%bsd,del1)
            tp%opik=opik_tpcar(tpcar,fail_flag2,del2,vt3)
            del=MATMUL(del2,del1)
! Chain rule: we compute dxde=dxdx1*dx1dx0*dx0de                        
            dxdx0=MATMUL(dxdx1,dx1dx0)
            dxde=MATMUL(dxdx0,dx0de) 
! d(opik elements)/de
            dee=MATMUL(del,dxde)
            CALL convertunc(unc_store,dee,tp%unc_opik)
! stretching and width: eigenvalues                                                          
            CALL rs(2,2,tp%unc_opik%g(4:5,4:5),eigval,1,axes,fv1,fv2,ierr) 
            DO  i=1,2 
               IF(eigval(i).gt.0.d0)THEN 
                  sig(i)=sqrt(eigval(i)) 
               ELSE 
                  write(*,*) 'str_clan: non positive eigenvalues ', eigval 
                  sig(i)=0.d0 
               ENDIF
            ENDDO
            tp%stretch=sig(2)
            tp%width=sig(1)
! d(csi,zeta)/de
            dtpcarde=MATMUL(del1(1:3,1:6),dxde)       
            dtpde(1:2,1:6,jc)=MATMUL(vt3(2:3,1:3),dtpcarde)
! weak direction           
            CALL weak_dir(unc_store%g,wdir,sdir,-1,coo_store,coord_store)
            wtp(1)=DOT_PRODUCT(dtpde(1,1:6,jc),wdir)*sdir 
            wtp(2)=DOT_PRODUCT(dtpde(2,1:6,jc),wdir)*sdir 
            tp%stretch_lov=sqrt(wtp(1)**2+wtp(2)**2) 
            tp%alpha_lov=atan2(-wtp(1),wtp(2)) 
! output variables                                                      
            IF(axes(1,2)*wtp(1)+axes(2,2)*wtp(2).lt.0.d0)THEN
               axes(1,2)=-axes(1,2) 
               axes(2,2)=-axes(2,2) 
            ENDIF
            sina=-axes(1,2) 
            cosa=axes(2,2) 
            tp%alpha=atan2(sina,cosa) 
         ENDIF
! if conversion to TP has failed....
         IF(fail_flag1.eq.6)THEN
           tp%tp_conv=.false.
         ELSEIF(fail_flag1.eq.0)THEN
           tp%tp_conv=.true.            
         ENDIF
! auxiliary variables
         tp%xytp=tpcar%coord
         tp%d=vsize(mtpcar%coord(1:3))
         tp%b=vsize(tpcar%coord(1:3))
         tp%v=vsize(mtpcar%coord(4:6))
         tp%moid=moid0
         tp%angmoid=angmoid
         tp%iplam=iplam
         tp%tcla=tcla(jc)
! theta, phi
         xpl=xplaj(1:3,njc)
         vpl=xplaj(4:6,njc)
         rop(1,1:3)=xpl*(1.d0/vsize(xpl))
         rop(2,1:3)=vpl-prscal(vpl,rop(1,1:3))*rop(1,1:3)
         rop(2,1:3)= rop(2,1:3)*(1.d0/vsize(rop(2,1:3)))
         CALL prvec(rop(1,1:3),rop(2,1:3),rop(3,1:3))
         vv=MATMUL(rop,tp%xytp(4:6))    
         dz=vv(1)**2+vv(3)**2
         IF (dz.le.100*epsilon(1.d0)) then
! remove singularity at theta=0, pi
           tp%phi=0.d0 
         ELSE
           tp%phi=atan2(vv(1), vv(3))
         ENDIF
         tp%theta=acos(vv(2)/tp%opik%coord(1))
         xx=MATMUL(rop,tp%xytp(1:3))
         rr(1,1:3)=vv/vsize(vv)
         rr(2,1:3)=rop(2,1:3)-prscal(rop(2,1:3),rr(1,1:3))*rr(1,1:3)
         rr(2,1:3)= rr(2,1:3)*(1.d0/vsize(rr(2,1:3)))
         CALL prvec(rr(1,1:3),rr(2,1:3),rr(3,1:3))
         xop=MATMUL(rr,xx)
!         CALL rotmt(-tp%phi,r1,2)
!         CALL rotmt(-tp%theta,r2,1)
!         rr=MATMUL(r2,r1)
!         rrt=TRANSPOSE(rr)
!         xop=MATMUL(rrt,xx)
         IF(abs(xop(1)).gt.1.d-8)THEN
            WRITE(*,*)' str_clan: prrrrr ', xop
         ENDIF         
         tp%txi=xop(3)
         tp%tze=xop(2)  
! tp is ready as tp_point: store it (on disk/in RAM)
         tp_store(jc)=tp       
         CALL wri_tppoint(tp,iuncla,covava)
! magnitude could be set, but not strictly needed
       ELSE
! case of MTP 
! ...but the covariance matrix is not always available                  
         IF(.not.covava)THEN 
! propagation with derivatives, but covariance matrix not available;    
! do we need to output the close approach record? Yes, in the old format
! for compatibility reasons                                             
            planam=ordnam(iplam) 
            lpla=lench(planam) 
            r=vsize(xcla(1,jc)) 
            rdot=prscal(xcla(1,jc),vcla(1,jc))/r 
! reference system with tpno as first axis,  
! and the projection of the normal to the ecliptic as third axis        
            vc0=vsize(vcla(1,jc)) 
            DO i=1,3 
               tpno(i)=vcla(i,jc)/vc0 
            ENDDO 
            v2(1)=0.d0 
            v2(2)=0.d0 
            v2(3)=1.d0 
            CALL mtp_ref(tpno,v2,v3(1,1),vt3(1,1)) 
! rotation to v3 reference system 
! computation of MTP coordinates and derivatives                        
            xx=MATMUL(vt3(1:3,1:3),xcla(1:3,jc)) ! CALL mulmav (vt3,3,3,xcla(1:3,jc),3,xx) 
            tpc(1:2)=xx(2:3)
            tpc(3)=vc0
            call mjddat(tcla(jc),iday,imonth,iyear,hour) 
            write(date,'(i4,a1,i2.2,a1,i2.2,f6.5)')                     &
     &           iyear,'/',imonth,'/',iday,hour/24d0                    
            WRITE(iuncla,100) planam(1:lpla),date,tcla(jc),r,rdot,      &
     &           (xcla(i,jc),i=1,3),(vcla(i,jc),i=1,3),tpc(1:3),moid0                 
  100       FORMAT(a,1x,a16,f12.5,1x,f11.8,e11.3,1x,6(1x,f11.8),        &
     &           3(1x,f11.8),1x,f10.6)
         ELSE 
! partials are always available if we are here                          
            nv =21 
! First parzial derivatives: rewrap vector into 6x6 matrix              
            DO i=1,nv 
               y2(i)=xcla(i,jc) 
               y2(i+nv)=vcla(i,jc) 
            ENDDO 
            CALL varwra(y2,dxdx1,nv*2,nv) 
! Chain rule: we compute dxde=dxdx1*dx1dx0*dx0de                        
            dxdx0=MATMUL(dxdx1,dx1dx0) ! call mulmat(dxdx1,6,6,dx1dx0,6,6,dxdx0) 
            dxde=MATMUL(dxdx0,dx0de)  ! call mulmat(dxdx0,6,6,dx0de,6,6,dxde) 
! reference system with tpno as first axis,                             
! and the projection of the normal to the ecliptic as third axis        
            vc0=vsize(vcla(1,jc)) 
            DO i=1,3 
               tpno(i)=vcla(i,jc)/vc0 
            ENDDO 
            v2(1)=0.d0 
            v2(2)=0.d0 
            v2(3)=1.d0 
            CALL mtp_ref(tpno,v2,v3,vt3) 
! obsolete:                                                             
! projection of planet velocity on normal plane to tpno as second axis  
!           CALL mtpref(tpno,xplaj(4,jc),v3,vt3)                        
! rotation to v3 reference system                                       
            CALL mtp_rot3(.true.,vt3,xcla(1,jc),vcla(1,jc),dxde, &
     &           unc_store%g,tpc,dtpdet(1,1,jc),sig,           &
     &           axes,tpr,svv,cxv,czv) 
! weak direction           
            CALL weak_dir(unc_store%g,wdir,sdir,-1,coo_store,coord_store)
            wtp(1)=DOT_PRODUCT(wdir,dtpdet(1:6,1,jc))*sdir 
            wtp(2)=DOT_PRODUCT(wdir,dtpdet(1:6,2,jc))*sdir 
            wtpv=DOT_PRODUCT(wdir,dtpdet(1:6,3,jc))*sdir 
            wtpr=sqrt(wtp(1)**2+wtp(2)**2) 
            wtpal=atan2(-wtp(1),wtp(2)) 
! output variables                                                      
            csi=tpc(1) 
            zeta=tpc(2) 
            stretch=sig(2) 
            width=sig(1) 
            IF(axes(1,2)*wtp(1)+axes(2,2)*wtp(2).lt.0.d0)THEN
               axes(1,2)=-axes(1,2) 
               axes(2,2)=-axes(2,2) 
            ENDIF 
            sina=-axes(1,2) 
            cosa=axes(2,2) 
            alpha=atan2(sina,cosa) 

! date and planet name                                                  
            planam=ordnam(iplam) 
            lpla=lench(planam) 
            numcla=numcla+1 
            CALL wri_clan(iuncla,planam(1:lpla),tcla(jc),xcla(1,jc),    &
     &           vcla(1,jc),csi,zeta,stretch,width,alpha,               &
     &           moid0,angmoid,wtpr,wtpal,wtpv,svv,cxv,czv)
         ENDIF 
       ENDIF
1   ENDDO

CONTAINS
! =================================================================     
! MTPROT3                                                               
! rotation to v3 reference system, but with information                 
! enough to convert to Opik Target plane                                
      SUBROUTINE mtp_rot3(batchcl,vt3,dx,dv,dxde,gc,                     &
     &        tpc,dtpdt,sig,axes,tpr,svv,cxv,czv)                      
!    + tcla,xpla not needed unless we compute yddot                     
      IMPLICIT NONE 
! input                                                                 
      LOGICAL batchcl 
! vt3= matrix to change coord to MTP reference (V_1=velocity unit vector
!      V_3= projection of some axis, e.g. orthogonal to ecliptic, on MTP
!      V_2=V_1 x V_3; note reversal of orientation)                     
! dx,dv= geocentric position and velocity, in ecliptic reference frame  
! dxde= jacobian of dx,dv with respect to elements                      
! gc  = covariance matrix of orbital elements                           
      DOUBLE PRECISION vt3(3,3),dx(3),dv(3),dxde(6,6),gc(6,6) 
! approached planet: coordinates, time of close approach                
!     DOUBLE PRECISION xpla(6),tcla  
!     TYPE(tp_point), INTENT(OUT) :: va_trace                             
! output                                                                
! tpc= 3-d MTP vector: x,z, V                                           
! dtpdt= jacobian of tpc w.r. to elements, trasnposed                  
! sig= semiaxes, axes= unit vector of axes of MTP confidence ellipse (si
! tpr= minimum distance                                                 
! svv= rms of velocity V                                                
! cxv,czv= correlation of V with x,z                                    
       DOUBLE PRECISION tpc(3),dtpdt(6,3),sig(2),axes(2,2),tpr 
       DOUBLE PRECISION svv,cxv,czv
! end interface                       
                                  
! xx,vv= position and velocity in MTP reference system                  
! dxde3,dvde3= reduced jacobians (only for multiplication)              
! dtpcde= jacobian of tpc w.r. to elements                              
      DOUBLE PRECISION xx(3),vv(3),dxde3(3,6),dvde3(3,6),dtpcde(3,6) 
! tpth= angle on MTP                                                    
      DOUBLE PRECISION tpth 
! dxxde,dvvde= jacobians w.r. to elements but in the MTP reference frame
      DOUBLE PRECISION dxxde(3,6),dvvde(3,6) 
! xhel,vhel= helicoentric position and velocity                         
! f=heliocentric acceleration                                           
! yddot= component of geocentric acceleration in the velocity direction 
! xxpla= position of the planet                                         
!     DOUBLE PRECISION xhel(3),vhel(3),f(3),xxpla(6),yddot              
!     INTEGER idc                                                       
! gxz= 2x2 covariance matrix on MTP                                     
! gmtp=3x3 covariance matrix on MTP                                     
! tmp1= workspace for multiplications                                   
      DOUBLE PRECISION gxz(2,2),gmtp(3,3),tmp1(3,6) 
! eigenvalues, workspace, transposed                                    
      DOUBLE PRECISION eigval(2),tmp26(2,6),fv1(2),fv2(2),dadde(2,6) 
! error flag                                                            
      INTEGER ierr 
! loop index                                                            
      INTEGER i,ii,jj 
      DOUBLE PRECISION vl,vsize,bsd,d,v,prscal,tmp 
! computation of MTP coordinates and derivatives                        
      xx=MATMUL(vt3,dx)
      IF(.not.batchcl)WRITE(*,*)' distance from target plane=',xx(1) 
      vv=MATMUL(vt3,dv)
      dxxde=MATMUL(vt3,dxde(1:3,1:6))
      dvvde=MATMUL(vt3,dxde(4:6,1:6))
! MTP x,z coordinates and derivatives with respect to elements          
      DO ii=1,2 
         tpc(ii)=xx(ii+1) 
        DO jj=1,6 
          dtpcde(ii,jj)=dxxde(ii+1,jj)-(vv(ii+1)/vv(1))*dxxde(1,jj) 
        ENDDO 
      ENDDO 
! MTP polar coordinates                                                 
      tpr=sqrt(tpc(1)**2+tpc(2)**2) 
! velocity and derivatives with respect to elements                     
      v=vsize(vv) 
!      DO jj=1,3                                                        
!       xhel(jj)=dx(jj)+xpla(jj)                                        
!       vhel(jj)=dv(jj)+xpla(3+jj)                                      
!     ENDDO                                                             
!     CALL force(xhel,vhel,tcla,f,3,idc,xxpla,0,10)                     
!      yddot=prscal(f,vv)/v                                             
! add velocity as third coordinate                                      
      tpc(3)=vv(1) 
      DO jj=1,6 
          dtpcde(3,jj)=dvvde(1,jj) 
! two-body approx: the acceleration of the Earth does not matter        
! for the other bodies, only differential accel. which is neglected     
!                                  -(yddot/vv(1))*dxxde(1,jj)           
      ENDDO 
      dtpdt=TRANSPOSE(dtpcde)
! output for interactive mode                                           
      IF(.not.batchcl)THEN 
         tpth=atan2(tpc(2),tpc(1))  
         WRITE(*,170) tpc,tpr,tpth 
  170    FORMAT('MTP coordinates ',2f12.8,' dist ',f12.8,' angle ',f8.4) 
         WRITE(*,*)' partial derivatives' 
         DO ii=1,3 
            WRITE(*,171) (dtpcde(ii,jj),jj=1,6) 
         ENDDO 
  171    FORMAT(6(f12.5,2x)) 
      ENDIF 
! ========================================================              
! compute target ellipse of confidence                                  
      tmp1=MATMUL(dtpcde,gc)
      gmtp=MATMUL(tmp1,dtpdt)
      CALL marg_2(gmtp,gxz,svv,cxv,czv) 
! compute ellipse of confidence                                         
! eigenvalues                                                           
      CALL rs(2,2,gxz,eigval,1,axes,fv1,fv2,ierr) 
      DO  i=1,2 
        IF(eigval(i).gt.0.d0)THEN 
           sig(i)=sqrt(eigval(i)) 
        ELSE 
           write(*,*) 'non positive eigenvalue' 
           sig(i)=0.d0 
        ENDIF 
      ENDDO 
      RETURN 
      END SUBROUTINE mtp_rot3   

      SUBROUTINE marg_2(gmtp,gxz,svv,cxv,czv) 
      IMPLICIT NONE 
! INPUT                                                                 
! gmtp= 3x3 covariance matrix on extended MTP                           
      DOUBLE PRECISION gmtp(3,3) 
! OUPUT                                                                 
! gxz= 2x2 covarioance matrix on MTP                                    
! svv= rms of velocity V                                                
! cxv,czv= correlation of V with x,z                                    
      DOUBLE PRECISION gxz(2,2),svv,cxv,czv 
      INTEGER i,j 
      DO i=1,2 
        DO j=1,2 
          gxz(i,j)=gmtp(i,j) 
        ENDDO 
      ENDDO 
      svv=sqrt(gmtp(3,3)) 
      cxv=gmtp(1,3)/sqrt(gmtp(3,3)*gmtp(1,1)) 
      czv=gmtp(2,3)/sqrt(gmtp(3,3)*gmtp(2,2)) 
      RETURN 
      END SUBROUTINE marg_2                                          

! ================================================                      
! WRICLAN                                                               
! writes close approach record with linear MTP analysis                 
! ====================================================                  
      SUBROUTINE wri_clan(iuncla,planam,tcla,xcla,vcla,                 &
     &     csi,zeta,stretch,width,alpha,moid0,angmoid,                  &
     &     wtpr,wtpal,wtpv,svv,cxv,czv) 
      USE fund_const                                              
      IMPLICIT NONE 
! INPUT        
! unit for output                                                       
      INTEGER, INTENT(IN) :: iuncla 
      CHARACTER(LEN=*), INTENT(IN) :: planam 
      TYPE(mtp_point) :: va_trace
! hidden output: array written on .clo file                             
      CHARACTER*16 date ! date
! planetocentric position and velocity, MJD time of closest approach    
      DOUBLE PRECISION xcla(3),vcla(3),tcla 
! target plane coordinates, 1-sigma axes of target plane ellipse and    
! angle between zeta axis and long axis (sign chosen with increasing a) 
      DOUBLE PRECISION csi,zeta,stretch,width,alpha 
! LOCAL MOID at beginning of encounter, angle between planet  positions 
      DOUBLE PRECISION moid0,angmoid 
! projection of LOV on target plane, polar coordinates, velocity compone
      DOUBLE PRECISION wtpr,wtpal,wtpv 
! third row of covariance on extended MTP                               
      DOUBLE PRECISION svv,cxv,czv 
! end interface                                                         
! distance, radial velocity (should be small,just for check)            
      DOUBLE PRECISION vsize,prscal 
      INTEGER j 
! ====================================================                  
      r=vsize(xcla) 
      rdot=prscal(xcla,vcla)/r 
      call mjddat(tcla,iday,imonth,iyear,hour) 
      write(date,'(i4,a1,i2.2,a1,i2.2,f6.5)')                           &
     &     iyear,'/',imonth,'/',iday,hour/24d0 
        ! copy in array                                                         
      va_trace%tcla=tcla 
      va_trace%rcla=r 
      va_trace%rdotcla=rdot 
      va_trace%xcla=xcla 
      va_trace%vcla=vcla 
      va_trace%tp_coord(1)=csi 
      va_trace%tp_coord(2)=zeta
      va_trace%tp_coord(3)=vsize(vcla) 
      va_trace%stretch=stretch 
      va_trace%width=width 
      va_trace%alpha=alpha*degrad 
      va_trace%moid=moid0 
      va_trace%angmoid=angmoid 
      va_trace%stretch_lov=wtpr 
      va_trace%alpha_lov=wtpal*degrad 
      va_trace%dvdsigma=wtpv 
      va_trace%svv=svv 
      va_trace%cxv=cxv 
      va_trace%czv=czv
      va_trace%dd2_ds=0.d0
      va_trace%sigma=0.d0
      va_trace%minposs=0.d0
      va_trace%moid_gf=0.d0
      va_trace%rindex=0.d0
      va_trace%tp_conv=.false.
      va_trace%cov_tp=.true.       
      mtp_store(jc)=va_trace
! file output                                                           
      WRITE(iuncla,100)planam,date,                                                &
      &           va_trace%tcla,va_trace%rcla,va_trace%rdotcla,                    &
      &           va_trace%xcla,va_trace%vcla,                                     &
      &           va_trace%tp_coord(1), va_trace%tp_coord(2),                      &
      &           va_trace%stretch,va_trace%width,va_trace%alpha,                  &
      &           va_trace%moid,va_trace%angmoid,                                  &
      &           va_trace%stretch_lov,va_trace%alpha_lov,                         &
      &           va_trace%dvdsigma,va_trace%svv,va_trace%cxv,va_trace%czv,        &
      &           va_trace%tp_coord(3)
!      &           va_trace%dd2_ds,va_trace%sigma,va_trace%minposs,                 &
!      &           va_trace%moid_gf,va_trace%rindex,va_trace%tp_conv,               &
!      &           va_trace%cov_tp                                 
 100 FORMAT(a15,1x,a16,f12.5,1x,f11.8,e11.3,1x,6(1x,f11.8),             &
     &     2(1x,f11.8),2(1x,1p,e12.4),1x,0p,f10.5,1x,f10.6,1x,f7.2,    &
     &     1x,1p,e12.4,0p,1x,f10.5,1x,1p,e15.8,1x,e15.8,1x,e15.8,       &
     &     1x,e15.8,1x,e15.8)
! giacomo              
!     &     f7.3,1x,f11.8,1x,e12.4,1x,f7.3,1x,f7.3,1x &
!     &     L5,1x,L5)
! standard output                                                       
      IF(verb_clo.gt.9)THEN 
      WRITE(*,97)planam,date,va_trace%tcla,va_trace%rcla,va_trace%tp_coord(1:2), &
     &            va_trace%stretch,va_trace%width,(va_trace%alpha),         &
     &           va_trace%moid,va_trace%angmoid,                                  &
     &           va_trace%stretch_lov,(va_trace%alpha_lov)                         
   97 FORMAT(' Close approach to ',a,' on ',a16,f13.5,' MJD at ',       &
     &     f10.8,' AU.'/2(1x,f11.8),2(1x,1p,e12.4),1x,0p,f10.5,1x,f10.6,&
     &     1x,f7.2,1x,1p,e12.4,0p,1x,f10.5)                             
      ENDIF 
      RETURN 
      END SUBROUTINE wri_clan   
END SUBROUTINE str_clan

  SUBROUTINE wri_tppoint(tp,iunclo,covav)
     USE planet_masses
     USE fund_const
     TYPE(tp_point), INTENT(IN) :: tp ! TP data structure
     INTEGER, INTENT(IN) :: iunclo ! output unit for clo file
     LOGICAL, INTENT(IN) :: covav ! is covariance available?
     DOUBLE PRECISION g(6,6),cor(6,6),rms(6)
! calendar date variables                                               
     INTEGER iyear,imonth,iday 
     DOUBLE PRECISION hour 
     CHARACTER*16 date 
! planet names                                                          
     CHARACTER*30 planam
     INTEGEr i,j
     planam=ordnam(tp%iplam)
     CALL mjddat(tp%tcla,iday,imonth,iyear,hour) 
     WRITE(date,'(i4,a1,i2.2,a1,i2.2,f6.5)') iyear,'/',imonth,'/',iday,hour/24d0
     IF(covav)THEN
        g=tp%unc_opik%g
        DO j=1,6
          rms(j)=sqrt(g(j,j))
        ENDDO
        DO i=2,6
          DO j=1,i-1
            cor(i,j)=g(i,j)/(rms(i)*rms(j))
          ENDDO
        ENDDO
        WRITE(iunclo,100)planam,date,tp%tcla,tp%d,tp%v,  tp%opik%coord(4:6), tp%tp_conv,   &
&        tp%stretch,tp%width,tp%alpha*degrad,tp%moid,tp%angmoid,tp%stretch_lov,tp%alpha_lov*degrad, &
&        tp%opik%coord(2:3)*degrad,tp%b,tp%opik%coord(1), tp%theta*degrad, tp%phi*degrad, tp%txi, tp%tze, &
&        tp%xytp,            & 
&        rms, cor(2:6,1), cor(3:6,2), cor(4:6,3), cor(5:6,4), cor(6,5) 
100     FORMAT(a10,1x,a16,f12.5,1x,f13.10,1x,f12.9,2(1x,f13.10),1x,1p,d10.3,0p,1x,L1/     &
&        2(1x,1p,e12.4),1x,0p,f10.5,1x,f10.6,1x,f7.2,1x,1p,e12.4,0p,1x,f10.5/         &
&        f10.6,1x,f11.6,1x,2(1x,f13.10),1x,f10.6,1x,f11.6,2(1x,f13.10)/6(1x,f12.9)/ &
&        1p,6(1x,d18.11)/0p,5(1x,f19.16)/5(1x,f19.16)/5(1x,f19.16))
     ELSE
        WRITE(iunclo,101)planam,date,tp%tcla,tp%d,tp%v, tp%opik%coord(4:6), tp%tp_conv,  &
&        tp%opik%coord(2:3)*degrad,tp%b,tp%opik%coord(1), tp%theta*degrad, tp%phi*degrad, tp%txi, tp%tze,&
&         tp%xytp
101     FORMAT(a10,1x,a16,f12.5,1x,f13.10,1x,f12.9,2(1x,f13.10),1x,1p,d10.3,0p,1x,L1/      &
&              f10.6,1x,f11.6,1x,2(1x,f13.10),1x,f10.6,1x,f11.6,2(1x,f13.10),6(1x,f12.9))  
     ENDIF
   END SUBROUTINE wri_tppoint

   SUBROUTINE rea_tppoint(tp,iunclo,covav)
     USE planet_masses
     USE fund_const
     TYPE(tp_point), INTENT(OUT) :: tp ! TP data structure
     INTEGER, INTENT(IN) :: iunclo ! output unit for clo file
     LOGICAL, INTENT(IN) :: covav ! is covariance available?
     DOUBLE PRECISION g(6,6),cor(6,6),rms(6)
! planet names                                                          
     CHARACTER*30 planam
     CHARACTER*16 date
     INTEGER j,i,le
     IF(covav)THEN
        READ(iunclo,100)planam,date,tp%tcla,tp%d,tp%v, tp%opik%coord(4:6), tp%tp_conv,   &
&        tp%stretch, tp%width, tp%alpha, tp%moid, tp%angmoid, tp%stretch_lov, tp%alpha_lov, &
&        tp%opik%coord(2:3),tp%b, tp%opik%coord(1), tp%theta, tp%phi, tp%txi, tp%tze, tp%xytp,& 
&        rms, cor(2:6,1), cor(3:6,2), cor(4:6,3), cor(5:6,4), cor(6,5) 
100     FORMAT(a10,1x,a16,f12.5,1x,f13.10,1x,f12.9,2(1x,f13.10),1x,1p,d10.3,0p,1x,L1/     &
&        2(1x,1p,e12.4),1x,0p,f10.5,1x,f10.6,1x,f7.2,1x,1p,e12.4,0p,1x,f10.5/         &
&        f10.6,1x,f11.6,1x,2(1x,f13.10),2(1x,f10.6),2(1x,f13.10)/6(1x,f12.9)/ &
&        1p,6(1x,d18.11)/0p,5(1x,f19.16)/5(1x,f19.16)/5(1x,f19.16))
        DO j=1,6
          g(j,j)=rms(j)**2
        ENDDO
        DO i=2,6
          DO j=1,i-1
            g(i,j)=cor(i,j)*(rms(i)*rms(j))
            g(j,i)=g(i,j)
          ENDDO
        ENDDO
        tp%unc_opik%g=g
     ELSE
        READ(iunclo,101)planam,date,tp%tcla, tp%d,tp%v, tp%opik%coord(4:6), tp%tp_conv,&
&        tp%opik%coord(2:3),tp%b, tp%opik%coord(1), tp%theta, tp%phi, tp%txi, tp%tze, tp%xytp
101     FORMAT(a10,1x,a16,f12.5,1x,f13.10,1x,f12.9,2(1x,f13.10),1x,1p,d10.3,0p,1x,L1/      &
&       f10.6,1x,f11.6,1x,2(1x,f13.10),2(1x,f10.6),2(1x,f13.10),6(1x,f12.9))  
     ENDIF
     tp%theta=tp%theta*radeg
     tp%phi=tp%phi*radeg
     tp%opik%coord(2:3)=tp%opik%coord(2:3)*radeg
     tp%iplam=0
     tp%bsd=tp%b/tp%d
     tp%alpha=tp%alpha*radeg
     tp%alpha_lov=tp%alpha_lov*radeg
     tp%angmoid=tp%angmoid*radeg
     tp%opik%coo='TPC'
     le=LEN_TRIM(planam)
     DO j=1,npla
       IF(index(ordnam(j),planam(1:le)).ne.0)THEN
          tp%iplam=j
          EXIT
       ENDIF
     ENDDO
     IF(tp%iplam.eq.0)THEN
        WRITE(*,*)'rea_tppoint: planam not found ', planam
        WRITE(*,*) ordnam(1:npla)
        STOP
     ENDIF
   END SUBROUTINE rea_tppoint
! =================================================================     
! REACLORECTP reads the next close approach record of the required planet 
! reqpla; if reqpla=' ', then all planets are required                  
! ==================================================================    
   SUBROUTINE rea_clorectp(iunclo,reqpla,imulcur,va_trace,               &
     &     planam,error,eof)                                           
! INPUT                                                                 
! required planet                                                       
     CHARACTER*15 reqpla 
! input unit                                                            
     INTEGER iunclo 
! OUTPUT                                                                
! planet found                                                          
     CHARACTER*15 planam 
! arrays with close approach data
     INTEGER, INTENT(INOUT) ::  imulcur 
     TYPE(tp_point), INTENT(OUT) :: va_trace
! error flag, end of file                                               
     LOGICAl error,eof 
! end interface                                                         
     CHARACTER*512 record 
     INTEGER ii 
     INTEGER le,le1 
! ---------------------------                                           
     eof=.false. 
     error=.false. 
1    READ(iunclo,101,end=2)record 
101  FORMAT(a) 
     CALL rmsp(reqpla,le) 
     ii=index(record,'mult_') 
     IF(ii.ne.0)THEN 
        READ(record(ii+5:),102)imulcur 
102     FORMAT(i5) 
        GOTO 1
     ELSE
        ii=index(record,reqpla(1:le)) 
        !         WRITE(*,*)ii,reqpla, record                                   
        IF(ii.ne.0)THEN 
           planam=reqpla 
           BACKSPACE(UNIT=iunclo)
           CALL rea_tppoint(va_trace,iunclo,.true.) 
        ELSEIF(le.eq.0)THEN 
           READ(record,103)planam 
           CALL rmsp(planam,le1) 
103        FORMAT(a15) 
           BACKSPACE(UNIT=iunclo)
           CALL rea_tppoint(va_trace,iunclo,.true.)
        ELSE 
           GOTO 1 
        ENDIF
     ENDIF
     RETURN 
2    eof=.true. 
   END SUBROUTINE rea_clorectp

! =================================================================     
! REACLOREC reads the next close approach record of the required planet 
! reqpla; if reqpla=' ', then all planets are required                  
! ==================================================================    
      SUBROUTINE rea_clorec(iunclo,reqpla,imulcur,va_trace,               &
     &     planam,error,eof)                                           
      IMPLICIT NONE 
! INPUT                                                                 
! required planet                                                       
      CHARACTER*15 reqpla 
! input unit                                                            
      INTEGER iunclo 
! OUTPUT                                                                
! planet found                                                          
      CHARACTER*15 planam 
! arrays with close approach data
      INTEGER imulcur 
      TYPE(mtp_point), INTENT(OUT) :: va_trace
! error flag, end of file                                               
      LOGICAl error,eof 
! end interface                                                         
      CHARACTER*512 record 
      INTEGER ii 
      INTEGER le,le1 
! ---------------------------                                           
      eof=.false. 
      error=.false. 
    1 READ(iunclo,101,end=2)record 
  101 FORMAT(a) 
      CALL rmsp(reqpla,le) 
      ii=index(record,'mult_') 
      IF(ii.ne.0)THEN 
         IF(imulcur.gt.0)THEN
            READ(record(ii+5:),102)imulcur 
  102       FORMAT(i5) 
            GOTO 1 
         ELSE 
            WRITE(*,*)' reaclorec: multiple solution clo file',record 
            GOTO 1 
         ENDIF 
      ELSE 
         ii=index(record,reqpla(1:le)) 
!         WRITE(*,*)ii,reqpla, record                                   
         IF(ii.ne.0.and.le.ne.0)THEN 
            planam=reqpla 
            CALL rea_clan(record,va_trace,error) 
         ELSEIF(le.eq.0)THEN 
            READ(record,103)planam 
            CALL rmsp(planam,le1) 
  103       FORMAT(a15) 
            CALL rea_clan(record,va_trace,error) 
         ELSE 
            GOTO 1 
         ENDIF 
      ENDIF 
      RETURN 
    2 eof=.true. 

   CONTAINS
        
        
       ! ================================================                      
! REACLAN reads record written by wriclan3, only data part, places in a
      SUBROUTINE rea_clan(record,va_trace,error) 
      IMPLICIT NONE 
! INPUT                                                                 
      CHARACTER*512 record 
! OUTPUT                                                                
      LOGICAL error 
      TYPE(mtp_point), INTENT(OUT) :: va_trace
!                                                                       
      INTEGER j 
      error=.false. 
      READ(record, 100, err=2)va_trace%tcla,va_trace%rcla,va_trace%rdotcla,        &
      &           va_trace%xcla,va_trace%vcla,                                     &
      &           va_trace%tp_coord(1),va_trace%tp_coord(2),                       &
      &           va_trace%stretch,va_trace%width,va_trace%alpha,                  &
      &           va_trace%moid,va_trace%angmoid,                                  &
      &           va_trace%stretch_lov,va_trace%alpha_lov,                         &
      &           va_trace%dvdsigma,va_trace%svv,va_trace%cxv,va_trace%czv,        &
      &           va_trace%tp_coord(3)        
!      &           va_trace%dd2_ds,va_trace%sigma,va_trace%minposs,                 &
!      &           va_trace%moid_gf,va_trace%rindex,va_trace%tp_conv,               &
!      &           va_trace%cov_tp
 100  FORMAT(32x,f12.5,1x,f11.8,e11.3,1x,6(1x,f11.8),                              &
     &     2(1x,f11.8),2(1x,1p,e12.4),1x,0p,f10.5,1x,f10.6,1x,f7.2,                &
     &     1x,1p,e12.4,0p,1x,f10.5,1x,                               &
     &     1p,e15.8,1x,e15.8,1x,e15.8,1x,e15.8,1x,e15.8) 
! giacomo             
!    100 FORMAT(32x,f12.5,1x,f11.8,e11.3,1x,6(1x,f11.8),                    &
!     &     3(1x,f11.8),2(1x,1p,e12.4),1x,0p,f10.5,1x,f10.6,1x,f7.2,    &
!     &     1x,1p,e12.4,0p,1x,f10.5,1x,                                  &
!     &     1p,e12.4,1x,e12.4,1x,e12.4,1x,e12.4) 
      RETURN 
    2 error=.true. 
      RETURN 
      END SUBROUTINE rea_clan  

   END SUBROUTINE rea_clorec
! SUBMODULE fclan
 

END MODULE tp_trace


! ================================================================      
! AFTCLOV                                                               
! select time interval to get after the close approach                  
! taking into account the relative velocity w.r. to Earth               
      SUBROUTINE aftclov(iplam,t0,tcla,v_inf,tbefore,tafter) 
      USE planet_masses
      IMPLICIT NONE 
! input: planet number, time of initial conditions,                     
! of known close approach, velocity                                     
      INTEGER iplam 
      DOUBLE PRECISION t0,tcla,v_inf 
! output: time "after", time "before" (depending upon sense of propagati
      DOUBLE PRECISION tafter,tbefore 
! end interface                                                         
! time interval to exit from TP disk                                    
      DOUBLE PRECISION delt_tp 
! target plane disk radius from planet_masses
! ===================================================================   
! warning: really done only for Earth                                   
      IF(ordnam(iplam).ne.'EARTH') THEN 
         WRITE(*,*)' aftclov: not to be used for planet ',ordnam(iplam) 
         delt_tp=180.d0 
! time interval to exit from TP disk
      ELSEIF(v_inf.gt.0.d0)THEN                                 
         delt_tp=2*dmin(iplam)/v_inf
      ELSE
         delt_tp=365.25d0
      ENDIF 
! forced to avoid infinte intervals for v-inf=0
      delt_tp=MIN(delt_tp,365.25d0)  
! forced to avoid short intervals for fast encounters                   
      IF(delt_tp.lt.50.d0)delt_tp=50.d0 
! time interval to be clear out of the TP disk is given as deltat       
      IF(t0.lt.tcla)THEN 
! future close approaches                                               
         tafter=tcla+delt_tp 
         tbefore=tcla-delt_tp 
      ELSE 
! past close approaches                                                 
         tafter=tcla-delt_tp 
         tbefore=tcla+delt_tp 
      ENDIF 
      RETURN 
      END SUBROUTINE aftclov 
! ===================================================
! velocity at infinity with repect to Earth
! (circular approx) in AU/day
DOUBLE PRECISION FUNCTION v_infty(el0)
  USE fund_const
  USE orbit_elements 
  IMPLICIT NONE 
! input elements
  TYPE(orbit_elem), INTENt(IN) :: el0
! END INTERFACE
  TYPE(orbit_elem) eleq
  DOUBLE PRECISION eq0(6) 
  DOUBLE PRECISION cosi,v2
  CHARACTER*3 coo
  INTEGER fail_flag
  coo=el0%coo
  CALL coo_cha(el0,'EQU',eleq,fail_flag)
  eq0=eleq%coord
  IF(fail_flag.eq.0)THEN 
! v_infinity computation in equinoctal
     cosi=(1.d0-eq0(4)**2-eq0(5)**2)/                                  &
     &     (1.d0+eq0(4)**2+eq0(5)**2)                                   
     v2=3.d0-1.d0/eq0(1) -                                             &
     &     2.d0*sqrt(eq0(1)*(1.d0-eq0(2)**2-eq0(3)**2))*cosi            
  ELSEIF(fail_flag.eq.5)THEN
! v_infinity computation in cometary
     cosi=cos(eq0(3))
     v2=3.d0-(1.d0-eq0(2))/eq0(1) - 2.d0*sqrt(eq0(1)*(1.d0+eq0(2)))*cosi
  ELSE
     WRITE(*,*)' v_infty: coordinate conversion failed ', el0,fail_flag  
  ENDIF
! handle non hyperbolic (w.r. to Earth) case
  IF(v2.gt.0.d0)THEN 
     v_infty=sqrt(v2) 
  ELSE 
     v_infty=0.d0 
  ENDIF
! normalization in AU/day by Gauss constant
  v_infty=v_infty*gk 
END FUNCTION v_infty









