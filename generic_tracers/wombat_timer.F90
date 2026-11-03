! SPDX-License-Identifier: MIT
!! Lightweight accumulating wall-clock timers for profiling the WOMBAT emulator.
!!
!! Modelled on pic_timer, but accumulates over many start/stop pairs so that the
!! cost per call (mean/min/max) can be reported, not just a single interval.
!!
!! Usage:
!!   type(wombat_timer_type) :: t_forward
!!   call t_forward%init('torch_model_forward')   ! once
!!   call t_forward%start()
!!   ...
!!   call t_forward%stop()
!!   call t_forward%report(unit)                  ! once, at the end
!!
!! Timers are disabled by default (zero overhead beyond a logical test) unless
!! wombat_timers_enabled is set true, so they can stay in production code.

module wombat_timer
  implicit none
  private

  public :: wombat_timer_type, wombat_timers_enabled

  integer, parameter :: dp = kind(1.0d0)
  integer, parameter :: i8 = selected_int_kind(18)

  logical :: wombat_timers_enabled = .false.

  type :: wombat_timer_type
    character(len=48) :: name = 'unnamed'
    integer(i8)       :: t_start = 0_i8
    integer(i8)       :: count_rate = 1_i8
    real(dp)          :: total = 0.0_dp
    real(dp)          :: tmin = huge(1.0_dp)
    real(dp)          :: tmax = 0.0_dp
    integer(i8)       :: ncalls = 0_i8
    logical           :: running = .false.
  contains
    procedure :: init   => timer_init
    procedure :: start  => timer_start
    procedure :: stop   => timer_stop
    procedure :: reset  => timer_reset
    procedure :: report => timer_report
  end type wombat_timer_type

contains

  subroutine timer_init(self, name)
    class(wombat_timer_type), intent(inout) :: self
    character(len=*),         intent(in)    :: name
    self%name = name
    call self%reset()
  end subroutine timer_init

  subroutine timer_reset(self)
    class(wombat_timer_type), intent(inout) :: self
    self%total   = 0.0_dp
    self%tmin    = huge(1.0_dp)
    self%tmax    = 0.0_dp
    self%ncalls  = 0_i8
    self%running = .false.
  end subroutine timer_reset

  subroutine timer_start(self)
    class(wombat_timer_type), intent(inout) :: self
    if (.not. wombat_timers_enabled) return
    call system_clock(self%t_start, self%count_rate)
    self%running = .true.
  end subroutine timer_start

  subroutine timer_stop(self)
    class(wombat_timer_type), intent(inout) :: self
    integer(i8) :: t_end
    real(dp)    :: dt
    if (.not. wombat_timers_enabled) return
    if (.not. self%running) return   ! tolerate a stop without a start
    call system_clock(t_end)
    if (self%count_rate <= 0_i8) return
    dt = real(t_end - self%t_start, dp) / real(self%count_rate, dp)
    self%total  = self%total + dt
    self%tmin   = min(self%tmin, dt)
    self%tmax   = max(self%tmax, dt)
    self%ncalls = self%ncalls + 1_i8
    self%running = .false.
  end subroutine timer_stop

  subroutine timer_report(self, unit, ref_total)
    !! Print one line: total, calls, mean/min/max per call in microseconds.
    !! If ref_total (seconds) is given, also print this timer as a % of it.
    class(wombat_timer_type), intent(in) :: self
    integer,                  intent(in) :: unit
    real(dp), optional,       intent(in) :: ref_total
    real(dp) :: mean_us
    character(len=16) :: pct

    if (self%ncalls == 0_i8) then
      write(unit, '(2x,a32,a)') self%name, '  (never called)'
      return
    endif

    mean_us = 1.0e6_dp * self%total / real(self%ncalls, dp)
    pct = ''
    if (present(ref_total)) then
      if (ref_total > 0.0_dp) write(pct, '(f7.2,a)') 100.0_dp*self%total/ref_total, ' %'
    endif
    write(unit, '(2x,a32,f12.4,i10,3f12.2,2x,a)') self%name, self%total, self%ncalls, &
         mean_us, 1.0e6_dp*self%tmin, 1.0e6_dp*self%tmax, trim(pct)
  end subroutine timer_report

end module wombat_timer
