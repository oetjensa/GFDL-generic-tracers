! Thin wrapper around FTorch for the remineralisation emulator.
! Keeps all FTorch calls in one place so the WOMBAT edits stay small.
!
! Feature order (must match training):
!   1 temperature   2 oxygen   3 detritus (det + bdet)   4 iron
!
! The FTorch tensors are created ONCE in remin_ftorch_init and wrap x_buf / y_buf
! without copying. Never reallocate x_buf / y_buf after init.
!
! NOTE: FTorch's API has changed between versions. This uses the subroutine form
! shown in the FTorch README. Check the examples/ folder of the version you install.
module remin_ftorch
  use, intrinsic :: iso_fortran_env, only : dp => real64
  use ftorch
  use, intrinsic :: ieee_exceptions
  implicit none
  private
  public :: remin_ftorch_init, remin_ftorch_predict, remin_ftorch_finalise

  integer, parameter :: n_feat = 4

  type(torch_model) :: model
  type(torch_tensor), dimension(1) :: in_tensors, out_tensors
  real(dp), allocatable, target :: x_buf(:,:)   ! (n_levels, n_feat)
  real(dp), allocatable, target :: y_buf(:)     ! (n_levels)
  integer :: n_levels = 0

contains

  subroutine remin_ftorch_init(model_path, nk)
    character(len=*), intent(in) :: model_path
    integer,          intent(in) :: nk        ! maximum number of levels in a column

    n_levels = nk
    allocate(x_buf(nk, n_feat), y_buf(nk))
    x_buf = 1.0_dp     ! harmless positive dummy values
    y_buf = 0.0_dp

    call torch_model_load(model, trim(model_path), torch_kCPU)
    call torch_tensor_from_array(in_tensors(1),  x_buf, torch_kCPU)
    call torch_tensor_from_array(out_tensors(1), y_buf, torch_kCPU)
  end subroutine remin_ftorch_init

  ! Predict the rate for one column. Only levels 1:n_wet are real; the rest are
  ! filled with dummy values (the model is pointwise, so they do not affect results).
  subroutine remin_ftorch_predict(temp, o2, detr, fe, n_wet, rate)
    real(dp), intent(in)  :: temp(:), o2(:), detr(:), fe(:)
    integer,  intent(in)  :: n_wet
    real(dp), intent(out) :: rate(:)
    type(ieee_flag_type), parameter :: trap_flags(3) = &
         [ieee_invalid, ieee_overflow, ieee_divide_by_zero]
    logical :: halting(3)

    x_buf = 1.0_dp
    x_buf(1:n_wet, 1) = temp(1:n_wet)
    x_buf(1:n_wet, 2) = o2(1:n_wet)
    x_buf(1:n_wet, 3) = detr(1:n_wet)
    x_buf(1:n_wet, 4) = fe(1:n_wet)

    ! The host model may be built with -fpe0 (trap on invalid/overflow/div-by-zero).
    ! libtorch's vectorised kernels can raise such exceptions harmlessly, so switch
    ! trapping off around the call, clear any raised flags, and restore afterwards.
    call ieee_get_halting_mode(trap_flags, halting)
    call ieee_set_halting_mode(trap_flags, .false.)

    call torch_model_forward(model, in_tensors, out_tensors)

    call ieee_set_flag(trap_flags, .false.)
    call ieee_set_halting_mode(trap_flags, halting)

    rate(1:n_wet) = y_buf(1:n_wet)
    if (size(rate) > n_wet) rate(n_wet+1:) = 0.0_dp
  end subroutine remin_ftorch_predict

  subroutine remin_ftorch_finalise()
    call torch_delete(model)
    call torch_delete(in_tensors)
    call torch_delete(out_tensors)
    deallocate(x_buf, y_buf)
  end subroutine remin_ftorch_finalise

end module remin_ftorch