#include "../defines.inc"
!-----------------------------------------------------------!
!
!         Calculate Energy dou to exteranl potential
!
!            Started by Quinn, Dec 2017
!     Sets: dEField and dx_Field based on R, RP, and, HA
!-----------------------------------------------------------

subroutine MC_external_field(wlc_p,IT1,IT2)
! values from wlcsim_data
use params, only: wlc_dx_externalField, wlc_dx_ExternalField, wlc_RP, wlc_DEExternalField, wlc_R
use params, only: dp,wlcsim_params, nan
implicit none
type(wlcsim_params), intent(in) :: wlc_p
integer, intent(in) :: IT1    ! Start test bead
integer, intent(in) :: IT2    ! Final test bead

integer ii
real(dp) vv(3)
real(dp), parameter :: center(3) = [WLC_P__LBOX_X/2.0_dp,&
                                    WLC_P__LBOX_Y/2.0_dp,&
                                    WLC_P__LBOX_Z/2.0_dp]
real(dp) centers(3)
integer ix,iy,iz
do ii = IT1, IT2
    if (WLC_P__CONFINETYPE == 'excludedShpereInPeriodic') then
        do ix=1,WLC_P__N_SPHERES_TO_SIDE
        do iy=1,WLC_P__N_SPHERES_TO_SIDE
        do iz=1,WLC_P__N_SPHERES_TO_SIDE
            centers(1)=(real(ix,dp)-0.5_DP)*WLC_P__LBOX_X/real(WLC_P__N_SPHERES_TO_SIDE,dp)
            centers(2)=(real(ix,dp)-0.5_DP)*WLC_P__LBOX_Y/real(WLC_P__N_SPHERES_TO_SIDE,dp)
            centers(3)=(real(ix,dp)-0.5_DP)*WLC_P__LBOX_Z/real(WLC_P__N_SPHERES_TO_SIDE,dp)
            vv(1) = modulo(wlc_RP(1,ii),WLC_P__LBOX_X)-centers(1)
            vv(2) = modulo(wlc_RP(2,ii),WLC_P__LBOX_Y)-centers(2)
            vv(3) = modulo(wlc_RP(3,ii),WLC_P__LBOX_Z)-centers(3)
            if (dot_product(vv,vv) < &
                (WLC_P__BINDING_R + WLC_P__CONFINEMENT_SPHERE_DIAMETER/2.0)**2) then
                wlc_dx_externalField = wlc_dx_externalField + 1.0_dp
            endif
            vv(1) = modulo(wlc_R(1,ii),WLC_P__LBOX_X)-centers(1)
            vv(2) = modulo(wlc_R(2,ii),WLC_P__LBOX_Y)-centers(2)
            vv(3) = modulo(wlc_R(3,ii),WLC_P__LBOX_Z)-centers(3)
            if (dot_product(vv,vv) < &
                (WLC_P__BINDING_R + WLC_P__CONFINEMENT_SPHERE_DIAMETER/2.0)**2) then
                wlc_dx_externalField = wlc_dx_externalField - 1.0_dp
            endif
        enddo
        enddo
        enddo
    elseif (WLC_P__CONFINETYPE == 'sphere') then
        vv(1) = modulo(wlc_RP(1,ii),WLC_P__LBOX_X)-center(1)
        vv(2) = modulo(wlc_RP(2,ii),WLC_P__LBOX_Y)-center(2)
        vv(3) = modulo(wlc_RP(3,ii),WLC_P__LBOX_Z)-center(3)
        if (dot_product(vv,vv) > &
            (-WLC_P__BINDING_R + WLC_P__CONFINEMENT_SPHERE_DIAMETER/2.0)**2) then
            wlc_dx_externalField = wlc_dx_externalField + 1.0_dp
        endif
        vv(1) = modulo(wlc_R(1,ii),WLC_P__LBOX_X)-center(1)
        vv(2) = modulo(wlc_R(2,ii),WLC_P__LBOX_Y)-center(2)
        vv(3) = modulo(wlc_R(3,ii),WLC_P__LBOX_Z)-center(3)
        if (dot_product(vv,vv) > &
            (-WLC_P__BINDING_R + WLC_P__CONFINEMENT_SPHERE_DIAMETER/2.0)**2) then
            wlc_dx_externalField = wlc_dx_externalField - 1.0_dp
        endif

    endif
enddo
wlc_DEExternalField = wlc_p%AEF * wlc_dx_ExternalField

END

subroutine MC_external_field_spider(wlc_p,spider_id)
! values from wlcsim_data
use params, only: wlc_spiders, wlc_dx_Externalfield
use params, only: wlcsim_params, dp
implicit none
TYPE(wlcsim_params), intent(in) :: wlc_p
integer, intent(in) :: spider_id
LOGICAL, parameter :: initialize = .False.  ! if true, calculate absolute energy
integer section_n,I1,I2

wlc_dx_Externalfield = 0.0_dp
do section_n = 1, wlc_spiders(spider_id)%nSections
    I1 = wlc_spiders(spider_id)%moved_sections(1,section_n)
    I2 = wlc_spiders(spider_id)%moved_sections(2,section_n)
    call MC_external_field(wlc_p,I1,I2)
enddo

end

subroutine MC_external_field_from_scratch(wlc_p)
! values from wlcsim_data
use params, only: wlc_dx_ExternalField, wlc_DEExternalField, wlc_R
use params, only: dp,wlcsim_params, nan
implicit none
type(wlcsim_params), intent(in) :: wlc_p

integer ii
real(dp) vv(3)
real(dp), parameter :: center(3) = [WLC_P__LBOX_X/2.0_dp,&
                                    WLC_P__LBOX_Y/2.0_dp,&
                                    WLC_P__LBOX_Z/2.0_dp]
real(dp) centers(3)
integer ix,iy,iz
wlc_dx_ExternalField = 0.0_dp
do ii = 1,WLC_P__NT
    if (WLC_P__CONFINETYPE == 'excludedShpereInPeriodic') then
        do ix=1,WLC_P__N_SPHERES_TO_SIDE
        do iy=1,WLC_P__N_SPHERES_TO_SIDE
        do iz=1,WLC_P__N_SPHERES_TO_SIDE
            centers(1)=(real(ix,dp)-0.5_DP)*WLC_P__LBOX_X/real(WLC_P__N_SPHERES_TO_SIDE,dp)
            centers(2)=(real(ix,dp)-0.5_DP)*WLC_P__LBOX_Y/real(WLC_P__N_SPHERES_TO_SIDE,dp)
            centers(3)=(real(ix,dp)-0.5_DP)*WLC_P__LBOX_Z/real(WLC_P__N_SPHERES_TO_SIDE,dp)
            vv(1) = modulo(wlc_R(1,ii),WLC_P__LBOX_X)-centers(1)
            vv(2) = modulo(wlc_R(2,ii),WLC_P__LBOX_Y)-centers(2)
            vv(3) = modulo(wlc_R(3,ii),WLC_P__LBOX_Z)-centers(3)
            if (dot_product(vv,vv) < &
                (WLC_P__BINDING_R + WLC_P__CONFINEMENT_SPHERE_DIAMETER/2.0)**2) then
                wlc_dx_ExternalField = wlc_dx_ExternalField + 1.0_dp
            endif
        enddo
        enddo
        enddo
    elseif (WLC_P__CONFINETYPE == 'sphere') then
        vv(1) = modulo(wlc_R(1,ii),WLC_P__LBOX_X)-center(1)
        vv(2) = modulo(wlc_R(2,ii),WLC_P__LBOX_Y)-center(2)
        vv(3) = modulo(wlc_R(3,ii),WLC_P__LBOX_Z)-center(3)
        if (dot_product(vv,vv) > &
            (-WLC_P__BINDING_R + WLC_P__CONFINEMENT_SPHERE_DIAMETER/2.0)**2) then
            wlc_dx_ExternalField = wlc_dx_ExternalField + 1.0_dp
        endif

    endif
enddo
wlc_DEExternalField = wlc_p%AEF * wlc_dx_ExternalField

END
