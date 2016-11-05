!This subroutine calculates the alexander polynomial of a chain represented by a set of 
!discrete beads after a crankshaft move has been performed. The routine updates the values
!in the Cross matrix that change during the move. This subroutine currently only works if there
!is one polymer

SUBROUTINE alexanderp_crank(R,N,Delta,Cross,CrossSize,NCross,IT1,IT2,DIB)
  IMPLICIT NONE
  !INPUT VARIABLES
  INTEGER N                     ! Number of points in space curve
  INTEGER CrossSize             !Size of the cross matrix (larger than the total number of crossings to prevent reallocation)
  DOUBLE PRECISION R(N,3)       !Space curve
  DOUBLE PRECISION Cross(CrossSize,6)        !Matrix of cross indices and coordinates
  DOUBLE PRECISION CrossNew(CrossSize,6)
  INTEGER Ncross                !Total number of crossings
  INTEGER NCrossNew
  INTEGER  IT1,IT2               !Indices of beads that bound the segment rotated during crankshaft move
  INTEGER DIB                   !Number of segments in the segment rotated
  INTEGER DIO                   !Number of segments outside the segment rotated
  !OUTPUT VARIABLES
  INTEGER  DELTA

  !INTERMEDIATE VARIABLES
  INTEGER IT1N,IT2N             !New indicies for segments that bound the crankshaft move. Necessary to capture part that changes when IT1=IT2
  DOUBLE PRECISION, ALLOCATABLE ::  A(:,:) ! Alexander polynomial matrix evaluated at t=-1
  DOUBLE PRECISION NV(3)        ! normal vector for projection
  DOUBLE PRECISION RP(N,3)      ! projection of R onto plane defined by NV
  DOUBLE PRECISION RDOTN(N)        ! Dot product of R and NV
  INTEGER Ndegen                ! number of crossings for a given segment
  INTEGER I,J,K,IP1,JP1,KP1           ! iteration indices
  DOUBLE PRECISION smax,tmax    ! length of segments in the projection
  DOUBLE PRECISION ui(3),uj(3)  ! tangent vectors of segments in the projection
  DOUBLE PRECISION udot         ! dot product of tangents in the projection
  DOUBLE PRECISION t
  DOUBLE PRECISION sint,tint    ! intersection coordinates for projected segments
  DOUBLE PRECISION srmax,trmax  ! maximum true length of segment (non-projected)
  DOUBLE PRECISION srint,trint  ! intersection coordinates in unprojected coordinates
  DOUBLE PRECISION uri(3),urj(3) ! tangent vectors of unprojected segments
  DOUBLE PRECISION DRI(3),DRJ(3) !Displacement vectors of unprojected segments
  DOUBLE PRECISION thetai,thetaj ! angle between real segment and projected segment
  INTEGER, ALLOCATABLE :: over_ind(:) !Vector of over_pass indices (index of over-pass of Nth crossing)
  DOUBLE PRECISION delta_double ! double precision form of delta. To be converted to integer
  INTEGER index,IND
  INTEGER II,IO,IIP1,IOP1
  LOGICAL Copy

  !Performance testing for development
  DOUBLE PRECISION TIME1
  DOUBLE PRECISION TIME2
  DOUBLE PRECISION DT_PRUNE
  DOUBLE PRECISION DT_INTERSECT


  !Set the normal vector for the plane of projection. Currently set to parallel to z axis
  NV=0.
  NV(3)=1.

  !Calculate the projection of R onto the projection plane
  DO I=1,N
     RDOTN(I)=R(I,1)*NV(1)+R(I,2)*NV(2)+R(I,3)*NV(3)
  ENDDO

  !Calculate the projection of the curve into the plane with normal NV

  DO I=1,N
     RP(I,:)=R(I,:)-RDOTN(I)*NV
  ENDDO

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !Update Cross matrix by removing all instances in which segments that are in the rotated 
  !segment appear. This is done by copying to a new matrix only the crossings that don't
  !involve the portion of the chain that was moved
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !If IT1=IT2, then the two segments that sandwich IT1 are changed, so the indices need to be updated
  !to calculate the part of the Cross matrix that changes
  IT1N=IT1
  IT2N=IT2

  IF (IT2N.EQ.IT1N) THEN
     IF (DIB.EQ.0) THEN
        IF (IT1N.NE.1.AND.IT1N.NE.N) THEN
           IT2N=IT1N+1
           IT1N=IT1N-1
        ELSEIF (IT1N.EQ.1) THEN
           IT2N=IT1N+1
           IT1N=N
        ELSEIF (IT1N.EQ.N) THEN
           IT2N=1
           IT1N=N-1
        ENDIF
     ENDIF

     IF (DIB.EQ.N) THEN
        IF (IT1N.NE.1.AND.IT1N.NE.N) THEN
           IT2N=IT1N-1
           IT1N=IT1N+1
        ELSEIF (IT1N.EQ.1) THEN
           IT1N=IT1N+1
           IT2N=N
        ELSEIF (IT1N.EQ.N) THEN
           IT2N=N-1
           IT1N=1
        ENDIF
     ENDIF

  ENDIF

  DIO=N-DIB
  II=IT1N
  IND=1
  NCrossNew=0
  CrossNew=0.
  !Copy the old cross matrix to the new cross matrix. Only copy rows in which intersections do not involve
  !one of the segments moved

  DO J=1,NCross
     Copy=.TRUE.
     II=IT1N
     DO I=1,DIB
        IF (II.EQ.N+1) THEN
           II=1
        ENDIF
        IF (II.EQ.nint(Cross(J,1)).OR.II.EQ.nint(Cross(J,2))) THEN
           Copy=.FALSE.
           EXIT
        ENDIF
        II=II+1
     ENDDO

     IF (Copy) THEN
        CrossNew(IND,:)=Cross(J,:)
        IND=IND+1
        NCrossNew=NCrossNew+1
     ENDIF
  ENDDO


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !Determine all crossings involving the segment rotated. Current method using a brute force search for all
  !intersections
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  CrossNew(:,5)=1.
  II=IT1N
  NCross=NCrossNew
  Cross=CrossNew
  !Loop over all segments within the portion of the chain that was moved

  DO I=1,DIB

     IF(II.EQ.N+1) THEN
        II=1
        IIP1=2
     ELSEIF (II.EQ.N) THEN
        IIP1=1
     ELSE
        IIP1=II+1
     ENDIF

     !Loop over all segments outside of the portion of the chain that was moved
     IO=IT2N
     DO J=1,DIO
        IF(IO.EQ.N+1) THEN
           IO=1
           IOP1=2
        ELSEIF (IO.EQ.N) THEN
           IOP1=1
        ELSE
           IOP1=IO+1
        ENDIF
        !Skip calculation for adjacent segments
        IF (II.EQ.IOP1.OR.IO.EQ.IIP1.OR.II.EQ.IO) THEN
           GOTO 10
        ENDIF

        !Calculate lengths of segments in the projection and the tangents
        smax=SQRT(SUM((RP(IIP1,:)-RP(II,:))**2))
        tmax=SQRT(SUM((RP(IOP1,:)-RP(IO,:))**2))
        ui=(RP(IIP1,:)-RP(II,:))/smax
        uj=((RP(IOP1,:)-RP(IO,:)))/tmax
        udot=ui(1)*uj(1)+ui(2)*uj(2)+ui(3)*uj(3)

        !If segments are parallel, continue to next segment
        IF (udot.EQ.1..OR.udot.EQ.-1.) THEN
           GOTO 10
        ENDIF

        !Compute the point of intersection
        tint=(rp(IO,2)-rp(II,2)-(ui(2)/ui(1))*(rp(IO,1)-rp(II,1)))/((ui(2)*uj(1)/ui(1))-uj(2))
        sint=(rp(IO,1)-rp(II,1)+uj(1)*tint)/ui(1)

        !If the intersection point is within length of segments, count as an intersection
        IF (sint.GE.0.AND.sint.LT.smax.AND.tint.GE.0.AND.tint.LT.tmax) THEN
           !Determine if this is an undercrossing (RI under RJ) or overcrossing

           !Compute lengths and tangents  of true segments (not projected)
           srmax=SQRT(SUM((R(IIP1,:)-R(II,:))**2))
           trmax=SQRT(SUM((R(IOP1,:)-R(IO,:))**2))
           DRI=R(IIP1,:)-R(II,:)
           DRJ=R(IOP1,:)-R(IO,:)
           uri=DRI/srmax
           urj=DRJ/trmax
           !Calculate the angle between the real segment and the projection
           thetai=ATAN(DRI(3)/smax)
           thetaj=ATAN(DRJ(3)/tmax)
           !Calculate point of intersection in the projection in terms of true length
           srint=sint/cos(thetai)
           trint=tint/cos(thetaj)

           !Determine whether this is an undercrossing or an overcrossing.
           !Save the indices appropriately (the index of the undercrossing segment 
           !must come first

           IF (R(II,3)+uri(3)*srint<r(IO,3)+urj(3)*trint) THEN
              Ncross=Ncross+1
              Cross(Ncross,1)=II;
              Cross(Ncross,2)=IO;
              Cross(Ncross,3)=sint;
              Cross(Ncross,4)=tint;
              Cross(Ncross,6)=-uj(2)*ui(1)+ui(2)*uj(1); !cross(ui,uj), + for RH, - for LH
           ELSE
              Ncross=Ncross+1
              Cross(Ncross,1)=IO
              Cross(Ncross,2)=II
              Cross(Ncross,3)=tint
              Cross(Ncross,4)=sint
              Cross(Ncross,6)=-(-uj(2)*ui(1)+ui(2)*uj(1)); !cross(ui,uj), + for RH, - for LH

           ENDIF
        ENDIF

10      CONTINUE
        IO=IO+1
     ENDDO

     !Loop over all segments inside the portion that was moved, up to the segment that lies before the segment
     !immediately adjacent to the II segment in the outermost loop

     IO=IT1N

     DO J=1,I-2
        IF(IO.EQ.N+1) THEN
           IO=1
           IOP1=2
        ELSEIF (IO.EQ.N) THEN
           IOP1=1
        ELSE
           IOP1=IO+1
        ENDIF
        !Skip calculation for adjacent segments
        IF (II.EQ.IOP1.OR.IO.EQ.IIP1.OR.II.EQ.IO) THEN
           GOTO 20
        ENDIF

        !Calculate lengths of segments in the projection and the tangents
        smax=SQRT(SUM((RP(IIP1,:)-RP(II,:))**2))
        tmax=SQRT(SUM((RP(IOP1,:)-RP(IO,:))**2))
        ui=(RP(IIP1,:)-RP(II,:))/smax
        uj=((RP(IOP1,:)-RP(IO,:)))/tmax
        udot=ui(1)*uj(1)+ui(2)*uj(2)+ui(3)*uj(3)

        !If segments are parallel, continue to next segment
        IF (udot.EQ.1..OR.udot.EQ.-1.) THEN
           GOTO 20
        ENDIF

        !Compute the point of intersection
        tint=(rp(IO,2)-rp(II,2)-(ui(2)/ui(1))*(rp(IO,1)-rp(II,1)))/((ui(2)*uj(1)/ui(1))-uj(2))
        sint=(rp(IO,1)-rp(II,1)+uj(1)*tint)/ui(1)

        !If the intersection point is within length of segments, count as an intersection
        IF (sint.GE.0.AND.sint.LT.smax.AND.tint.GE.0.AND.tint.LT.tmax) THEN
           !Determine if this is an undercrossing (RI under RJ) or overcrossing

           !Compute lengths and tangents  of true segments (not projected)
           srmax=SQRT(SUM((R(IIP1,:)-R(II,:))**2))
           trmax=SQRT(SUM((R(IOP1,:)-R(IO,:))**2))
           DRI=R(IIP1,:)-R(II,:)
           DRJ=R(IOP1,:)-R(IO,:)
           uri=DRI/srmax
           urj=DRJ/trmax
           !Calculate the angle between the real segment and the projection
           thetai=ATAN(DRI(3)/smax)
           thetaj=ATAN(DRJ(3)/tmax)
           !Calculate point of intersection in the projection in terms of true length
           srint=sint/cos(thetai)
           trint=tint/cos(thetaj)

           !Determine whether this is an undercrossing or an overcrossing.
           !Save the indices appropriately (the index of the undercrossing segment 
           !must come first

           IF (R(II,3)+uri(3)*srint<r(IO,3)+urj(3)*trint) THEN
              Ncross=Ncross+1
              Cross(Ncross,1)=II;
              Cross(Ncross,2)=IO;
              Cross(Ncross,3)=sint;
              Cross(Ncross,4)=tint;
              Cross(Ncross,6)=-uj(2)*ui(1)+ui(2)*uj(1); !cross(ui,uj), + for RH, - for LH
           ELSE
              Ncross=Ncross+1
              Cross(Ncross,1)=IO
              Cross(Ncross,2)=II
              Cross(Ncross,3)=tint
              Cross(Ncross,4)=sint
              Cross(Ncross,6)=-(-uj(2)*ui(1)+ui(2)*uj(1)); !cross(ui,uj), + for RH, - for LH

           ENDIF
        ENDIF

20      CONTINUE
        IO=IO+1
     ENDDO

     II=II+1
  ENDDO

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !Continue with the alexander polynomial calculation as usual. The remainder is no different
  !from the subroutine that calclates the alexander polynomial from scratch (i.e. w/o a Cross matrix
  !from the previous move.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Sort the undercrossings according to order of occurrence. The undercrossings that come first
  !as you traverse the chain along its contour length come first. Hence, sort based on the first column of Cross

  CALL bubble_sort(Cross(1:Ncross,:),Ncross,6,1)


  !Sort under-crossings of same segment with respect to order of occurrence (w.r.t sint)

  index=1

  DO WHILE (index.LT.Ncross)
     !Determine the number of degenerate crossings for the current segment index
     Ndegen=1
     DO WHILE (nint(Cross(index+Ndegen,1)).EQ.nint(Cross(index,1)))
        Ndegen=Ndegen+1
     ENDDO
     IF (Ndegen.GT.1) THEN
        CALL bubble_sort(Cross(index:index+Ndegen-1,:),Ndegen,6,3)
     ENDIF
     Cross(index:index+Ndegen-1,5)=Ndegen
     index=index+Ndegen

  ENDDO


  !Construct vector of over-pass indices according to indexing described by Vologodskii
  !The element in the Nth row is the index of the segment that overpasses the Nth crossing

  ALLOCATE(over_ind(Ncross))

  DO I=1,Ncross
     !get original polymer index of overpass
     J=Cross(I,2)
     !Special cases: j compes before first crossing or
     !after the last crossing
     IF (J.LT.nint(Cross(1,1))) THEN
        over_ind(I)=1
     ELSEIF (J.GT.nint(Cross(Ncross,1))) THEN
        over_ind(I)=Ncross+1
     ENDIF

     !Sum over all crossings to determine which undercrossing this lies between
     DO K=1,Ncross
        !If J lies between cross K and cross K+1, then it is segment K+1
        IF (J.GT.nint(Cross(K,1)).AND.J.LT.nint(Cross(K+1,1))) THEN
           over_ind(I)=K+1
           GOTO 30 
           !If J=K, then segment j contains undercrossings
           ! then need to determine where overpass lies relative to undercrossing
        ELSEIF (J.EQ.nint(CROSS(K,1))) THEN
           t=Cross(I,4)
           Ndegen=Cross(K,5)
           !Special case: t is before the first under-pass or after the last under-pass
           !of segment j
           IF (t.LE.Cross(K,3)) THEN
              over_ind(I)=K
              GOTO 30 
           ELSEIF (t.GE.Cross(K+Ndegen-1,3)) THEN
              OVER_IND(I)=K+Ndegen
              GOTO 30 
              !Otherwise, determine which under-crossings t lies between
           ELSE
              IND=1
              !loop over all degenerate undercrossings
              DO WHILE (IND.LT.Ndegen)
                 !if t lies between the s of undercrossing k+ind-1 and the next,
                 !then this over_pass has a new index of k+ind in the re-indexing
                 !scheme 
                 IF (t.GT.Cross(K+IND-1,3).AND.t.LT.CROSS(k+IND,3)) THEN
                    over_ind(I)=K+IND
                    GOTO 30 
                 ENDIF
                 IND=IND+1
              ENDDO
           ENDIF
        ENDIF

     ENDDO
30   CONTINUE

  ENDDO


  !Calculate the Alexander matrix evaluated at t=-1
  ! Note that the Alexander matrix is correct only up to 
  ! a factor of +-1. Since the alexander polynomial evaluated 
  ! at t=-1 is always positive, take the absolute value of the
  ! determinant


  ALLOCATE(A(Ncross,Ncross))
  A=0.

  DO K=1,Ncross
     KP1=K+1
     I=over_ind(K)
     !Periodic index conditions
     IF (K.EQ.Ncross) THEN
        KP1=1
     ENDIF

     IF (I.GE.Ncross+1) THEN
        I=1
     ENDIF

     !calculate values of the matrix
     IF (I.EQ.K.OR.I.EQ.KP1) THEN
        A(K,K)=-1.
        A(K,KP1)=1.
     ELSE 
        A(K,K)=1.
        A(K,KP1)=1.
        A(K,I)=-2.
     ENDIF

  ENDDO

  !Calculate the determinant of the matrix with one row and one column removed 


  !If A has one crossing or less, it is the trivial knot

  IF (Ncross.LE.1) THEN
     delta_double=1.
  ELSE 
     CALL abs_determinant(A(1:Ncross-1,1:Ncross-1),NCross-1,delta_double)
  ENDIF

  delta=nint(delta_double)

  !Deallocate Arrays

  DEALLOCATE(A)
  DEALLOCATE(over_ind)

  RETURN

END SUBROUTINE alexanderp_crank
