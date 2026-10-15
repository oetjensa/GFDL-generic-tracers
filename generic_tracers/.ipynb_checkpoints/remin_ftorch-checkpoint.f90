! AO with CLAUDE (01/10/2026)
!Thin wrapper around FTorch for the remineralisation emulator.
! Keeps all FTorch calls in one place so the WOMBAT edits stay small.
!
! Feature order (must match training):
!   1 temperature   2 oxygen   3 detritus (det + bdet)   4 iron
!
! Two ways to call it:
!   remin_ftorch_predict       - one call per COLUMN (efficient; preferred)
!   remin_ftorch_predict_point - one call per grid CELL (convenient; slower, since
!                                every call pays the libtorch call overhead)
!
! The FTorch tensors are created ONCE in remin_ftorch_init and wrap module-level
! buffers without copying. Never reallocate the buffers after init.
!
! Not thread-safe (module-level buffers): do not call from inside an OpenMP region.
!
! NOTE: FTorch's API has changed between versions. This uses the subroutine form
! shown in the FTorch README. Check the examples/ folder of the version you install.
module remin_ftorch
  use, intrinsic :: iso_fortran_env, only : dp => real64
  use ftorch
  use, intrinsic :: ieee_exceptions
  implicit none
  private
  public :: remin_ftorch_init, remin_ftorch_predict, remin_ftorch_predict_point, &
            remin_ftorch_finalise

  integer, parameter :: n_feat = 4

  type(torch_model) :: model

  ! column buffers / tensors
  type(torch_tensor), dimension(1) :: in_tensors, out_tensors
  real(dp), allocatable, target :: x_buf(:,:)   ! (n_levels, n_feat)
  real(dp), allocatable, target :: y_buf(:)     ! (n_levels)
  integer :: n_levels = 0

  ! single-point buffers / tensors
  type(torch_tensor), dimension(1) :: in1_tensors, out1_tensors
  real(dp), allocatable, target :: x1_buf(:,:)  ! (1, n_feat)
  real(dp), allocatable, target :: y1_buf(:)    ! (1)

contains

  subroutine remin_ftorch_init(model_path, nk)
    character(len=*), intent(in) :: model_path
    integer,          intent(in) :: nk        ! maximum number of levels in a column

    if (allocated(x_buf)) return              ! already initialised

    n_levels = nk
    allocate(x_buf(nk, n_feat), y_buf(nk))
    allocate(x1_buf(1, n_feat), y1_buf(1))
    x_buf  = 1.0_dp     ! harmless positive dummy values
    y_buf  = 0.0_dp
    x1_buf = 1.0_dp
    y1_buf = 0.0_dp

    call torch_model_load(model, trim(model_path), torch_kCPU)
    call torch_tensor_from_array(in_tensors(1),   x_buf,  torch_kCPU)
    call torch_tensor_from_array(out_tensors(1),  y_buf,  torch_kCPU)
    call torch_tensor_from_array(in1_tensors(1),  x1_buf, torch_kCPU)
    call torch_tensor_from_array(out1_tensors(1), y1_buf, torch_kCPU)
  end subroutine remin_ftorch_init

  ! Predict the rate for one column. Only levels 1:n_wet are real; the rest are
  ! filled with dummy values (the model is pointwise, so they do not affect results).
  subroutine remin_ftorch_predict(temp, o2, detr, fe, n_wet, rate)
    real(dp), intent(in)  :: temp(:), o2(:), detr(:), fe(:)
    integer,  intent(in)  :: n_wet
    real(dp), intent(out) :: rate(:)
    logical :: halting(3)

    if (n_wet > n_levels) error stop 'remin_ftorch_predict: n_wet exceeds nk given to init'
    rate = 0.0_dp
    if (n_wet < 1) return

    x_buf = 1.0_dp
    x_buf(1:n_wet, 1) = temp(1:n_wet)
    x_buf(1:n_wet, 2) = o2(1:n_wet)
    x_buf(1:n_wet, 3) = detr(1:n_wet)
    x_buf(1:n_wet, 4) = fe(1:n_wet)

    call traps_off(halting)
    call torch_model_forward(model, in_tensors, out_tensors)
    call traps_restore(halting)

    rate(1:n_wet) = y_buf(1:n_wet)
  end subroutine remin_ftorch_predict

  ! Predict the rate for a single grid cell.
  function remin_ftorch_predict_point(temp, o2, detr, fe) result(rate)
    real(dp), intent(in) :: temp, o2, detr, fe
    real(dp) :: rate
    logical :: halting(3)

    x1_buf(1, 1) = temp
    x1_buf(1, 2) = o2
    x1_buf(1, 3) = detr
    x1_buf(1, 4) = fe

    call traps_off(halting)
    call torch_model_forward(model, in1_tensors, out1_tensors)
    call traps_restore(halting)

    rate = y1_buf(1)
  end function remin_ftorch_predict_point

  subroutine remin_ftorch_finalise()
    call torch_delete(model)
    call torch_delete(in_tensors)
    call torch_delete(out_tensors)
    call torch_delete(in1_tensors)
    call torch_delete(out1_tensors)
    deallocate(x_buf, y_buf, x1_buf, y1_buf)
  end subroutine remin_ftorch_finalise

  ! The host model may be built with -fpe0 (trap on invalid/overflow/div-by-zero).
  ! libtorch's vectorised kernels can raise such exceptions harmlessly, so switch
  ! trapping off around the call, clear any raised flags, and restore afterwards.
  subroutine traps_off(halting)
    logical, intent(out) :: halting(3)
    type(ieee_flag_type), parameter :: trap_flags(3) = &
         [ieee_invalid, ieee_overflow, ieee_divide_by_zero]
    call ieee_get_halting_mode(trap_flags, halting)
    call ieee_set_halting_mode(trap_flags, .false.)
  end subroutine traps_off

  subroutine traps_restore(halting)
    logical, intent(in) :: halting(3)
    type(ieee_flag_type), parameter :: trap_flags(3) = &
         [ieee_invalid, ieee_overflow, ieee_divide_by_zero]
    call ieee_set_flag(trap_flags, .false.)
    call ieee_set_halting_mode(trap_flags, halting)
  end subroutine traps_restore

end module remin_ftorch