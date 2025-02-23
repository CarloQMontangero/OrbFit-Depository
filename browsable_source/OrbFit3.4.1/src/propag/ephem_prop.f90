! ============ephem_prop===================                             
! PUBLIC ROUTINES:                                                      
!                  fstpro                                             
!                  fsteph                                               
!                  ephemc                                               
! INTERNAL                                                              
! ROUTINES                                                              
!                  srtept                                               
!                  outco                                                
!                                                                       
!  MODULES; NO HEADERS! 
!   ephem_prop.o: \
!	../suit/FUND_CONST.mod \
!	pred_obs.o \
!	propag_state.o                                                    

!                                                                       
! ====================================================                  
! FSTPRO state propagation for FITOBS                                   
! ====================================================                  
SUBROUTINE fstpro(batch,icov,ini0,cov0,iun20,iun8,ok,             &
     &    el0,unc0,tr,el1,unc1)
  USE fund_const   
  USE orbit_elements 
  USE propag_state                     
  IMPLICIT NONE 
! =================INPUT=========================================       
! requirements on covariance                                            
  INTEGER, INTENT(IN) :: icov 
! batch mode                                                            
  LOGICAL, INTENT(IN) :: batch 
! availability of initial conditions, covariance, all required          
  LOGICAL, INTENT(IN) :: ini0
  LOGICAL, INTENT(INOUT) :: cov0 ! set to false if covariance not propagated
! output units                                                          
  INTEGER, INTENT(IN) :: iun20,iun8 
! target time                                               
  DOUBLE PRECISION, INTENT(IN) :: tr 
! elements, magnitude, covariance and normal matrix
  TYPE(orbit_elem), INTENT(IN) :: el0
  TYPE(orb_uncert), INTENT(IN) :: unc0
! ================OUTPUT=================================               
! elements, magnitude, covariance and normal matrix at epoch tr
  LOGICAL, INTENT(OUT) :: ok ! feasible         
  TYPE(orbit_elem), INTENT(INOUT) :: el1
  TYPE(orb_uncert), INTENT(INOUT) :: unc1
! ================END INTERFACE==========================               
! loop indexes                                                          
  INTEGER ii,j 
! ===================================================================== 
! check availability of required data                                   
  CALL chereq(icov,ini0,cov0,el0%t,iun20,ok) 
  IF(.not.ok)RETURN 
! ===================================================================== 
! check availability of JPL ephemerides                                  
  CALL chetim(el0%t,tr,ok) 
  IF(.not.ok) THEN 
     WRITE(*,*)' JPL ephemrides not available for tr=',tr 
     ok=.false. 
     RETURN 
  ENDIF
! ===================================================================== 
! propagation to time tr                                                
  IF(icov.eq.1)THEN 
! state vector only                                                     
     CALL pro_ele(el0,tr,el1) 
     cov0=.false. 
     unc1%succ=.false.
  ELSEIF(icov.eq.2)THEN 
     CALL pro_ele(el0,tr,el1,unc0,unc1) 
  ENDIF
! ===================================================================== 
! output                                                                
! ===================================================================== 
  IF(.not.batch.and.iun20.gt.0)THEN 
     WRITE(iun20,223) tr 
     WRITE(*,223) tr 
223  FORMAT(' elements at time ',f8.1,' (MJD):') 
     WRITE(*,105) el1%coo, el1%coord 
     WRITE(iun20,105) el1%coo, el1%coord 
     WRITE(*,*) 
     WRITE(iun20,*) 
105  FORMAT(A3,6(1x,f13.7)) 
     IF(icov.eq.2.and.iun8.gt.0)THEN 
        WRITE(iun8,*) 'COVARIANCE MATRIX FOR NEW EPOCH' 
        WRITE(iun8,223) tr 
        CALL outco(iun8,unc1%g,unc1%c) 
     ENDIF
  ENDIF
END SUBROUTINE fstpro
! Copyright 1998 Orbfit Consortium                                      
! Version December 18, 1998 Steven Chesley (chesley@dm.unipi.it)        
! Version 3.3.1/2 February 2006, A. Milani
! ====================================================                  
! FSTEPH Ephemerides Generation for FITOBS                              
! This is a hacked version of FSTPRO                                    
! Inntegrate from t0 both back and forward as required
! Then write this data in chronological order                           
! inputs:                                                               
!     name - asteroid name (for file and ephem listing)                 
!     dir - location for files                                          
!     defele - logical for existence of elements
!     el0 - input elements                                              
!     tr - initial time for ephemerides                                 
!     tf - final time                                                   
!     step - stepsize                                                   
!     numsav - an upper bound for the number of steps necessary before t
!     ephefl - logical flag for output of ephemrides file               
!     eltype - coordinate type for ephemerides (output) elements (EQU,CA
!     moidfl - logical flag for output of file of MOID's and nodal dista
! output:
!     ok - success flag                      
!                                                                       
! REMARK: IF moidfl=.false. and ephefl=.false. you will still           
!     get a close approach file.                                        
! ====================================================                  
SUBROUTINE fsteph(name,dir,defele,ok,el0,                &
     &     tr,tf,step,numsav,ephefl,cooy,moidfl)
  USE fund_const
  USE orbit_elements 
  USE propag_state 
  IMPLICIT NONE 
! =================INPUT=========================================       
! name, place, output element type                                      
  CHARACTER*(*), INTENT(IN) :: name,dir 
! availability of initial conditions and covariance, required output          
  LOGICAL, INTENT(IN) ::  defele,moidfl,ephefl 
! necessary size of temporary storage array                             
  INTEGER, INTENT(IN) ::  numsav 
! times, elements                                                 
  DOUBLE PRECISION, INTENT(IN) ::  tr,tf,step
  TYPE(orbit_elem), INTENT(IN) :: el0
  CHARACTER*(3), INTENT(IN) :: cooy
! ================OUTPUT=================================               
  LOGICAL, INTENT(OUT) :: ok
! ================END INTERFACE==========================               
! loop indexes, no of records, no record before t0
  INTEGER i,n, nrec, nbef 
! converted elements 
  TYPE(orbit_elem) :: elem0, elem1
! temporary storage                                                     
  INTEGER, PARAMETER :: numsavx=10000
  TYPE(orbit_elem) :: elsav(numsavx)
  DOUBLE PRECISION tsav(numsavx),t1,t2,t0 
  INTEGER jst, fail_flag
! output                                                                
  INTEGER unit 
  INTEGER ln,lnm,lnnam 
  CHARACTER*(60) file,filem 
! moid                                                                  
  double precision moid,dnp,dnm 
  double precision msav(numsavx),ndsav(numsavx,2) 
  integer munit,icsav(numsavx) 
! ===================================================================== 
! check dimensions                                                      
!      WRITE(*,*)'fstpeh: t0,tr,tf',t0,tr,tf                            
  IF(numsav.gt.numsavx)THEN 
     WRITE(*,*)'fsteph: numsav=',numsav,' is > numsavx=', numsavx 
     RETURN 
  ENDIF
! check availability of required data                                   
  ok=.true. 
  IF (.not.defele)THEN 
     WRITE(*,*) 'Sorry: You must provide an orbit first.' 
     ok = .false. 
  ENDIF
  IF (tr .ge. tf)THEN 
     WRITE(*,*) 'Sorry: Initial time must be before final time.' 
     ok = .false. 
  ENDIF
  IF(.not.ok)RETURN 
! ===================================================================== 
! check availability of JPL ephemrides                                  
  call chetim(tr,tf,ok) 
  if(.not.ok)return 
!========= OPEN FILES =================================                 
  if(ephefl)then 
! open ephemerides ouput file                                           
     call filnam(dir,name,'ele',file,ln) 
     call filopn(unit,file(1:ln),'unknown') 
     call wro1lh(unit,'ECLM','J2000',cooy) 
  endif
  if(moidfl)then 
! open moid file                                                        
     call filnam(dir,name,'moid',filem,lnm) 
     call filopn(munit,filem(1:lnm),'unknown') 
  endif
  call rmsp(name,lnnam) 
!========= CONVERT INPUT ELEMENTS TO PROPAGATION TYPE ===============     
  CALL coo_cha(el0,'CAR',elem0,fail_flag)
  t0=el0%t
! ======== CREATE LIST OF TIMES, FIND ONE JUST BEFORE t0 ============
  nbef=0 ! if all after, nbef=0
  DO jst=1,numsavx
    tsav(jst)=tr+(jst-1)*step
    IF(tsav(jst).le.t0) nbef=jst ! maximum index of tsav.le.t0 
    IF(tsav(jst).gt.tf)EXIT
  ENDDO
  nrec=jst-1 ! no of records
  
!========= PROPAGATE, SAVE, AND THEN WRITE IN TIME ORDER ===============
!     step back in time first (if necessary)                            
  IF(tr .le. t0)THEN
     elem1=elem0
     CALL set_restart(.true.)
     IF(nbef.eq.0) STOP ' ***** fsteph: logic error 1 **********' 
! backward loop
     DO n=nbef,1,-1 
        t2=tsav(n)
        call pro_ele(elem1,t2,elem1)
        CALL set_restart(.false.)
        if(moidfl)then 
           call nomoid(t2,elem1,moid,dnp,dnm) 
        endif
        msav(n)=moid 
        icsav(n)=0
        ndsav(n,1)=dnp 
        ndsav(n,2)=dnm 
        elsav(n)=elem1
     ENDDO
  ENDIF
  IF(tf.gt.t0)THEN
     CALL set_restart(.true.)
     elem1=elem0
     IF(nbef.eq.nrec) STOP ' ***** fsteph: logic error 2 **********' 
! forward loop                                                     
     DO n=nbef+1,nrec 
        t2=tsav(n)
        call pro_ele(elem1,t2,elem1) 
        CALL set_restart(.false.) 
        if(moidfl)then 
           call nomoid(t2,elem1,moid,dnp,dnm) 
        endif  
        msav(n)=moid 
        ndsav(n,1)=dnp 
        ndsav(n,2)=dnm 
        icsav(n)=0 
        elsav(n)=elem1
     ENDDO
     CALL set_restart(.true.) 
!        write in forward time order                                    
     do i=1,nrec 
        IF(ephefl)THEN
           CALL coo_cha(elsav(i),cooy,elem1,fail_flag)
           CALL write_elems(elem1,name(1:lnnam),'1L',file,unit)
        ENDIF
        if(moidfl) write(munit,199)tsav(i),msav(i),ndsav(i,1),ndsav(i,2)                                  
199     format(f13.4,1x,f8.5,1x,f8.5,1x,f8.5) 
     enddo
  endif
! ===================================================================== 
  if(ephefl) call filclo(unit,' ') 
  if(moidfl) call filclo(munit,' ') 
  if(ephefl) write(*,*)'Ephemeris file generated:',file(1:ln) 
  if(moidfl) write(*,*)'Moid file generated:',filem(1:lnm) 
END SUBROUTINE fsteph

! Copyright (C) 1997-2000 by Mario Carpino (carpino@brera.mi.astro.it)  
! Version: December 11, 2000                                            
! --------------------------------------------------------------------- 
!                                                                       
!  *****************************************************************    
!  *                                                               *    
!  *                         E P H E M C                           *    
!  *                                                               *    
!  *                 Computation of ephemerides                    *    
!  *                                                               *    
!  *****************************************************************    
!                                                                       
! INPUT:    UNIT      -  Output FORTRAN unit                            
!           EL0       -  Orbital elements, including
!                        Type of orbital elements (EQU/KEP/CAR/COM)         
!                        Epoch of orbital elements (MJD, TDT)           
!                        Orbital elements (ECLM J2000)                  
!           UNC0      -  Covariance/normal matrix of orbital elements
!           DEFCOV    -  Tells whether the covariance matrix is defined 
!           T1        -  Starting time for ephemeris (MJD, TDT)         
!           T2        -  Ending time for ephemeris (MJD, TDT)           
!           DT        -  Ephemeris stepsize (d)                         
!           IDSTA     -  Station identifier                             
!           SCALE     -  Timescale for output                           
!           FIELDS    -  Output fields (separated by commas)            
!                                                                       
! SUPPORTED OUTPUT FIELDS:                                              
!     cal       calendar date                                           
!     mjd       Modified Julian Day                                     
!     coord     coordinates (RA and DEC, or ecliptic long. and lat.)    
!     mag       magnitude                                               
!     delta     distance from the Earth                                 
!     r         distance from the Sun                                   
!     elong     Sun elongation angle                                    
!     phase     Sun phase angle                                         
!     glat      galactic latitude                                       
!     appmot    apparent motion                                         
!     skyerr    sky plane error                                         
!                                                                       
SUBROUTINE ephemc(unit,el0,unc0,defcov,t1,t2,dt,idsta,scale,fields) 
  USE fund_const
  USE pred_obs
  USE orbit_elements                 
  IMPLICIT NONE 
  
  INTEGER unit,idsta 
  CHARACTER*(*) scale,fields 
  TYPE(orbit_elem), INTENT(IN) :: el0
  TYPE(orb_uncert), INTENT(IN) :: unc0
  DOUBLE PRECISION t1,t2,dt
  LOGICAL defcov 
                                                                        
  DOUBLE PRECISION, PARAMETER :: epst=1.d-6 

! Max number of output fields                                           
  INTEGER, PARAMETER :: nfx=30 
! Max number of ephemeris points                                        
  INTEGER, PARAMETER :: nephx=600 
! Max length of output records                                          
  INTEGER, PARAMETER :: lrx=200 
                                         
  INTEGER nf,lh,ider,i,lf,lr,day,month,year,ia,ma,id,md,ls,neph,k,ip 
  INTEGER srtord(nephx),lrv(nephx),iepfor,la,lad,lfo,lf1,lf2 
  INTEGER inb1,inb2,inl 
  CHARACTER*(1), PARAMETER :: obstyp='O'       
  DOUBLE PRECISION tdt,alpha,delta,mag,hour,sa,sd,difft,signdt,cvf 
  DOUBLE PRECISION alpha1,delta1,mag1,gamad1(2,2) ! for test comparison
  DOUBLE PRECISION gamad(2,2),sig(2),axes(2,2),err1,err2,pa 
  DOUBLE PRECISION teph(nephx),velsiz 
  CHARACTER*1 siga,sigd,anguni 
  CHARACTER*3 cmonth(12) 
  CHARACTER*20 field(nfx),frameo,amuni,amunid,amfor 
  CHARACTER*(lrx) head1,head2,head3,head4,outrec,recv(nephx),blank 
  CHARACTER cval*80 
  LOGICAL outmot,outerr,outmag,oldrst,found,fail1,fail,usexp 
! Time conversion (added by Steve Chesley)                              
  INTEGER mjdt,mjdout 
  DOUBLE PRECISION sect,secout,tout 
  DOUBLE PRECISION :: adot,ddot ! proper motion
  DOUBLE PRECISION :: pha,dis,dsun,elo,gallat ! phase, distance to Earth, distance to Sun                                                 
  INTEGER lench 
  EXTERNAL lench 
                                                                        
  DATA cmonth/'Jan','Feb','Mar','Apr','May','Jun',                  &
     &            'Jul','Aug','Sep','Oct','Nov','Dec'/                  
                                                                        
  inb1=3 
  inb2=2                                                                    
! Parameter which should become options                                 
  frameo='EQUATORIAL' 
  signdt=1 
  IF(dt.LT.0) signdt=-1 
! List of ephemeris epochs                                              
  neph=0 
  tdt=t1 
2 CONTINUE 
  difft=signdt*(tdt-t2) 
  IF(difft.LE.epst) THEN 
     neph=neph+1 
     IF(neph.GT.nephx) STOP '**** ephemc: neph > nephx ****' 
     teph(neph)=tdt 
     tdt=t1+neph*dt 
     GOTO 2 
  END IF
                                                                        
! Sorting of ephemeris epochs                                           
  CALL srtept(teph,neph,el0%t,srtord) 
                                                                        
! List of output fields                                                 
  CALL spflds(fields,field,nf,nfx) 
                                                                        
! COMPOSITION OF HEADER LINES                                           
  head1=' ' 
  head2=' ' 
  head3=' ' 
  head4=' ' 
  blank=' ' 
  lh=0 
  outmot=.false. 
  outerr=.false. 
  ider=0 
                                                                        
  DO 5 i=1,nf 
     IF(field(i).EQ.'cal') THEN 
        head1(lh+1:)=blank 
        head2(lh+1:)='    Date      Hour ' 
        ls=lench(scale) 
        WRITE(head3(lh+1:),300) scale(1:ls) 
        head4(lh+1:)=' =========== ======' 
        lh=lh+19 
     ELSEIF(field(i).EQ.'mjd') THEN 
        head1(lh+1:)=blank 
        head2(lh+1:)='     MJD     ' 
        ls=lench(scale) 
        WRITE(head3(lh+1:),301) scale(1:ls) 
        head4(lh+1:)=' ============' 
        lh=lh+13 
     ELSEIF(field(i).EQ.'coord') THEN 
        IF(frameo.EQ.'EQUATORIAL') THEN 
           head1(lh+1:)='     Equatorial coordinates  ' 
           head2(lh+1:)='       RA            DEC     ' 
        ELSEIF(frameo.EQ.'ECLIPTICAL') THEN 
           head1(lh+1:)='      Ecliptic coordinates   ' 
           head2(lh+1:)='    Longitude      Latitude  ' 
        ELSE 
           lf=lench(frameo) 
           WRITE(*,331) frameo(1:lf) 
           STOP '**** ephemc: Abnormal end ****' 
        END IF
        head3(lh+1:)='    h  m  s        d  ''  "   ' 
        head4(lh+1:)='  =============  ============' 
        lh=lh+29 
     ELSEIF(field(i).EQ.'delta') THEN 
        head1(lh+1:)=blank 
        head2(lh+1:)='  Delta ' 
        head3(lh+1:)='   (AU) ' 
        head4(lh+1:)=' =======' 
        lh=lh+8 
     ELSEIF(field(i).EQ.'r') THEN 
        head1(lh+1:)=blank 
        head2(lh+1:)='    R   ' 
        head3(lh+1:)='   (AU) ' 
        head4(lh+1:)=' =======' 
        lh=lh+8 
     ELSEIF(field(i).EQ.'elong') THEN 
        head1(lh+1:)=blank 
        head2(lh+1:)=' Elong' 
        head3(lh+1:)=' (deg)' 
        head4(lh+1:)=' =====' 
        lh=lh+6 
     ELSEIF(field(i).EQ.'phase') THEN 
        head1(lh+1:)=blank 
        head2(lh+1:)=' Phase' 
        head3(lh+1:)=' (deg)' 
        head4(lh+1:)=' =====' 
        lh=lh+6 
     ELSEIF(field(i).EQ.'mag') THEN 
        outmag=(el0%h_mag.GT.-100.d0) 
        IF(outmag) THEN 
           head1(lh+1:)=blank 
           head2(lh+1:)='  Mag ' 
           head3(lh+1:)='      ' 
           head4(lh+1:)=' =====' 
           lh=lh+6 
        END IF
     ELSEIF(field(i).EQ.'glat') THEN 
        head1(lh+1:)=blank 
        head2(lh+1:)=' Glat ' 
        head3(lh+1:)=' (deg)' 
        head4(lh+1:)=' =====' 
        lh=lh+6 
     ELSEIF(field(i).EQ.'skyerr') THEN 
        IF(defcov) THEN 
           outerr=.true. 
           ider=1 
           head1(lh+1:)=blank 
           head2(lh+1:)='       Sky plane error    ' 
           head3(lh+1:)='     Err1      Err2    PA ' 
           head4(lh+1:)='  ========  ======== =====' 
           lh=lh+26 
        END IF
     ELSEIF(field(i).EQ.'appmot') THEN 
        fail=.false. 
! Default format for apparent motion:
! IEPFOR = 1 -> (Vx, Vy)                                                
! IEPFOR = 2 -> (V, PosAng)                                             
        iepfor=1 
        CALL sv2int('ephem.appmot.','format',cval,iepfor,.false.,     &
     &                found,fail1,fail)                                 
        amunid='"/min' 
        amuni=amunid 
        CALL rdncha('ephem.appmot.','units',amuni,.false.,            &
     &                found,fail1,fail)                                 
        IF(fail) STOP '**** ephemc: abnormal end ****' 
! CVF = conversion factor from rad/d to selected unit                   
        CALL angvcf(amuni,cvf,fail) 
        IF(fail) THEN 
           la=lench(amuni) 
           lad=lench(amunid) 
           WRITE(*,320) amuni(1:la),amunid(1:lad) 
           amuni=amunid 
           CALL angvcf(amuni,cvf,fail) 
           IF(fail) STOP '**** ephemc: internal error (01) ****' 
        END IF
        la=lench(amuni) 
! Choice of the output format: normally F format is preferred           
        amfor='(F10.4)' 
! LFO = length of the output string                                     
        lfo=10 
        usexp=.false. 
! Check whether F format can supply the required dynamic range          
        IF(1.D0*cvf.GE.500.D0) usexp=.true. 
        IF(3.D-3*cvf.LE.0.1D0) usexp=.true. 
! Otherwise use exponential format                                      
        IF(usexp) THEN 
           amfor='(1P,E12.4)' 
           lfo=12 
        END IF
        lf1=lfo 
        IF(iepfor.EQ.1) THEN 
           lf2=lfo 
        ELSE 
           lf2=6 
        END IF
        CALL filstr('App. motion',cval,lf1+lf2,inb1,0) 
        head1(lh+1:)=cval 
        IF(iepfor.EQ.1) THEN 
           CALL filstr('RA*cosDE',cval,lf1,inb1,0) 
        ELSE 
           CALL filstr('Vel',cval,lf1,inb1,0) 
        END IF
        head2(lh+1:)=cval 
        CALL filstr(amuni,cval,lf1,inb1,0) 
        head3(lh+1:)=cval 
        head4(lh+1:)='  ==================' 
        lh=lh+lf1 
        IF(iepfor.EQ.1) THEN 
           CALL filstr('DEC',cval,lf2,inb1,0) 
           head2(lh+1:)=cval 
           CALL filstr(amuni,cval,lf2,inb1,0) 
           head3(lh+1:)=cval 
           head4(lh+1:)='  ==================' 
        ELSE 
           CALL filstr('PA',cval,lf2,inb2,0) 
           head2(lh+1:)=cval 
           CALL filstr('deg',cval,lf2,inb2,0) 
           head3(lh+1:)=cval 
           head4(lh+1:)=' =====' 
        END IF
        lh=lh+lf2 
        outmot=.true. 
     ELSE 
        lf=lench(field(i)) 
        WRITE(*,330) field(i)(1:lf) 
        STOP '**** ephemc: abnormal end ****' 
     END IF
     IF(lh.GT.lrx) STOP '**** ephemc: lh > lrx ****' 
5 END DO
300 FORMAT('             (',A,') ') 
301 FORMAT('    (',A,')    ') 
330 FORMAT('Sorry, I don''t know how to produce field "',A,'"') 
331 FORMAT('Sorry, I don''t know "',A,'" reference system') 
320 FORMAT('WARNING(ephemc): I do not know how to use "',A,           &
     &    '" as units for apparent motion;'/                            &
     &    17X,'using instead default units "',A,'"')                    
  WRITE(unit,100) head1(1:lh) 
  WRITE(unit,100) head2(1:lh) 
  WRITE(unit,100) head3(1:lh) 
  WRITE(unit,100) head4(1:lh) 
100 FORMAT(A) 
   
  CALL set_restart(.true.) 
                                                                        
! Start loop on ephemeris epochs                                        
  DO 1 k=1,neph 
     ip=srtord(k) 
     tdt=teph(ip) 
! Numerical integration 
     inl=1                                                
     IF(outerr) THEN 
        CALL predic_obs(el0,idsta,tdt,obstyp,      &
     &        alpha,delta,mag,inl,                                    &
     &        UNCERT=unc0,GAMAD=gamad,SIG=sig,AXES=axes,              &
     &        ADOT0=adot,DDOT0=ddot,DIS0=dis,PHA0=pha,DSUN0=dsun,   &
     &        ELO0=elo,GALLAT0=gallat)
     ELSE 
        CALL predic_obs(el0,idsta,tdt,obstyp,  &
     &        alpha,delta,mag,inl,        &
     &        ADOT0=adot,DDOT0=ddot,DIS0=dis,PHA0=pha,DSUN0=dsun,   &
     &        ELO0=elo,GALLAT0=gallat)
     END IF
     CALL set_restart(.false.) 
                                                                        
! COMPOSITION OF OUTPUT RECORD                                          
! Time scale conversion                                                 
     mjdt=FLOOR(tdt) 
     sect=(tdt-mjdt)*86400.d0 
     CALL cnvtim(mjdt,sect,'TDT',mjdout,secout,scale) 
     tout=secout/86400.d0+mjdout 
!                                                                       
     outrec=' ' 
     lr=0 
     DO 6 i=1,nf 
! Calendar date                                                         
       IF(field(i).EQ.'cal') THEN 
          CALL mjddat(tout,day,month,year,hour) 
          IF(month.LT.1 .OR. month.GT.12)                               &
  &        STOP '**** ephemc: internal error (02) ****'              
          WRITE(outrec(lr+1:),201) day,cmonth(month),year,hour 
          lr=lr+19 
! Modified Julian Day                                                   
       ELSEIF(field(i).EQ.'mjd') THEN 
          WRITE(outrec(lr+1:),202) tout 
          lr=lr+13 
! Astrometric coordinates                                               
       ELSEIF(field(i).EQ.'coord') THEN 
          CALL sessag(alpha*hrad,siga,ia,ma,sa) 
          IF(siga.NE.'+') STOP '**** ephemc: internal error (03) ****' 
          CALL sessag(delta*degrad,sigd,id,md,sd) 
          WRITE(outrec(lr+1:),203) ia,ma,sa,sigd,id,md,sd 
          lr=lr+29 
! Distance from the Earth                                               
       ELSEIF(field(i).EQ.'delta') THEN 
          WRITE(outrec(lr+1:),204) dis 
          lr=lr+8 
! Distance from the Sun                                                 
       ELSEIF(field(i).EQ.'r') THEN 
          WRITE(outrec(lr+1:),204) dsun 
          lr=lr+8 
! Solar elongation                                                      
       ELSEIF(field(i).EQ.'elong') THEN 
          WRITE(outrec(lr+1:),205) elo*degrad 
          lr=lr+6 
! Solar phase angle                                                     
       ELSEIF(field(i).EQ.'phase') THEN 
          WRITE(outrec(lr+1:),205) pha*degrad 
          lr=lr+6 
! Magnitude                                                             
       ELSEIF(field(i).EQ.'mag') THEN 
          IF(outmag) THEN 
             WRITE(outrec(lr+1:),205) mag 
             lr=lr+6 
          END IF
! Sky plane error                                                       
       ELSEIF(field(i).EQ.'skyerr') THEN 
          IF(outerr) THEN 
             err1=sig(1)*degrad 
             err2=sig(2)*degrad 
! correction A. Milani 19/3/2000: remember right ascension increases    
! from right to left                                                    
!             pa=ATAN2(axes(2,1),axes(1,1))                             
             pa=ATAN2(axes(2,1),-axes(1,1)) 
             anguni='d' 
             IF(MAX(err1,err2).LT.1.d0) THEN 
                err1=err1*60 
                err2=err2*60 
                anguni='''' 
                IF(MAX(err1,err2).LT.1.d0) THEN 
                   err1=err1*60 
                   err2=err2*60 
                   anguni='"' 
                END IF
             END IF
             WRITE(outrec(lr+1:),208) err2,anguni,err1,anguni,pa*degrad 
             lr=lr+26 
          END IF
! Galactic latitude                                                     
       ELSEIF(field(i).EQ.'glat') THEN 
          WRITE(outrec(lr+1:),205) gallat*degrad 
          lr=lr+6 
! Apparent motion      CORRECTED 9 Jan 2003
       ELSEIF(field(i).EQ.'appmot') THEN 
          IF(iepfor.EQ.1) THEN 
             WRITE(outrec(lr+1:),amfor) adot*cvf*cos(delta) 
             lr=lr+lf1 
             WRITE(outrec(lr+1:),amfor) ddot*cvf 
             lr=lr+lf2 
          ELSE 
             velsiz=SQRT((adot*cos(delta))**2+ddot**2)
             WRITE(outrec(lr+1:),amfor) velsiz*cvf 
             lr=lr+lf1 
             pa=ATAN2(adot*cos(delta),ddot) 
             IF(pa.LT.0.D0) pa=pa+dpig 
             WRITE(outrec(lr+1:),205) pa*degrad 
             lr=lr+6 
          END IF 
       ELSE 
          lf=lench(field(i)) 
          WRITE(*,340) field(i)(1:lf) 
          STOP '**** ephemc: internal error (04) ****' 
       END IF
6   END DO
201 FORMAT(I3,1X,A3,I5,F7.3) 
202 FORMAT(F13.6) 
203 FORMAT(2X,2I3,F7.3,2X,A1,I2,I3,F6.2) 
204 FORMAT(F8.4) 
205 FORMAT(F6.1) 
207 FORMAT(2F8.4) 
208 FORMAT(2(F9.3,A1),F6.1) 
340 FORMAT(' ERROR: illegal output field "',A,'"') 
    IF(lr.GT.lrx) STOP '**** ephemc: lr > lrx ****' 
    recv(ip)=outrec(1:lr) 
    lrv(ip)=lr 
1 END DO
                                                                        
! CALL set_restart(.true.) 
                                                                        
                                                                        
! Output of ephemeris records in the required order                     
 DO 3 ip=1,neph 
    lr=lrv(ip) 
    WRITE(unit,100) recv(ip)(1:lr) 
3 END DO
                                                                        
END SUBROUTINE ephemc
! Copyright (C) 1997 by Mario Carpino (carpino@brera.mi.astro.it)       
! Version: December 12, 1997                                            
! --------------------------------------------------------------------- 
!                                                                       
!  *****************************************************************    
!  *                                                               *    
!  *                         S R T E P T                           *    
!  *                                                               *    
!  *                 Sorting of ephemeris epochs                   *    
!  *                                                               *    
!  *****************************************************************    
!                                                                       
! INPUT:    T         -  Ephemeris epochs                               
!           N         -  Number of ephemeris epochs                     
!           T0        -  Epoch of initial conditions                    
!                                                                       
! OUTPUT:   IPT       -  Sorting pointer                                
!                                                                       
SUBROUTINE srtept(t,n,t0,ipt) 
  IMPLICIT NONE 
  INTEGER n,ipt(n) 
  DOUBLE PRECISION t(n),t0 
                                                                        
  INTEGER i,i1,i2,k1,k2,nit 
  LOGICAL ge1,ge2,rev,change 
                                                                        
! Initial guess for IPT (assuming ephemeris times to be sorted          
! in ascending order)                                                   
  i1=n+1 
  DO 1 i=1,n 
     IF(t(i).GE.t0) THEN 
        i1=i 
        GOTO 2 
     END IF
1 END DO
2 CONTINUE 
! I1 is now the number of the first t(i)>=t0                            
  i2=0 
  DO 3 i=i1,n 
     i2=i2+1 
     ipt(i2)=i 
3 END DO
  DO 4 i=i1-1,1,-1 
     i2=i2+1 
     ipt(i2)=i 
4 END DO
  IF(i2.NE.n) STOP '**** srtept: internal error (01) ****' 
                                                                        
! Sorting                                                               
  nit=0 
5 CONTINUE 
  nit=nit+1 
  IF(nit.GT.n+3) STOP '**** srtept: internal error (02) ****' 
  change=.false. 
  DO 6 k1=1,n-1 
     k2=k1+1 
     i1=ipt(k1) 
     i2=ipt(k2) 
     ge1=(t(i1).GE.t0) 
     ge2=(t(i2).GE.t0) 
     IF(ge1) THEN 
        IF(ge2) THEN 
           rev=(t(i1).GT.t(i2)) 
        ELSE 
           rev=.false. 
        END IF
     ELSE 
        IF(ge2) THEN 
           rev=.true. 
        ELSE 
           rev=(t(i1).LT.t(i2)) 
        END IF
     END IF
     IF(rev) THEN 
        i=ipt(k1) 
        ipt(k1)=ipt(k2) 
        ipt(k2)=i 
        change=.true. 
     END IF
6 END DO
  IF(change) GOTO 5 
                                                                        
END SUBROUTINE srtept
! ===================================================================== 
! OUTCO                                                                 
! ===================================================================== 
!  output of covariance, computation of eigenvalues                     
!   input: iun   = output unit                                          
!          gamma = covariance matrix                                    
!          c     = normal matrix                                        
SUBROUTINE outco(iun,gamma,c) 
  implicit none 
! output unit, error flag                                               
  integer iun,ierr 
! loop indexes                                                          
  integer i,j 
! covariance, normal matrix                                             
  double precision gamma(6,6),c(6,6) 
! eigenvalues, eigenvectors                                             
  double precision eigvec(6,6),eigval(6),fv1(6),fv2(6) 
! output covariance                                                     
  write(iun,*) 
  write(iun,*) 'COVARIANCE MATRIX' 
  do j=1,6 
     write(iun,109) (gamma(i,j),i=1,6) 
109  format(6e24.16) 
  enddo
! eigenvalues                                                           
  call rs(6,6,gamma,eigval,1,eigvec,fv1,fv2,ierr) 
  write(iun,*) 
  write(iun,*) 'EIGENVALUES ' 
  write(iun,109) (eigval(i),i=1,6) 
  write(iun,*) 
  write(iun,*) 'EIGENVECTORS' 
  do 3 j=1,6 
! by columns (check)                                                    
     write(iun,109) (eigvec(i,j),i=1,6) 
3 ENDDO
  write(iun,*) 
  write(iun,*) 'NORMAL MATRIX' 
  do j=1,6 
     write(iun,109) (c(i,j),i=1,6) 
  enddo
END SUBROUTINE outco
