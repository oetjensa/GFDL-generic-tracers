
# GFDL generic tracers - **This is the development branch for WOMBAT-hy**

This fork is to experiment on the implementation of FTorch within WOMBAT, it contains the model code and a description of the changes made to call a Torchscript at runtime.  
See *https://github.com/oetjensa/WOMBAT_hybrid* for more details about the experiment configuration.  

This is a fork of the [NOAA-GFDL/ocean_BGC](https://github.com/NOAA-GFDL/ocean_BGC) repo managed by NOAA-GFDL. It contains a collection of tracers and associated code for use with the MOM and GOLD ocean models.  

This fork includes generic tracer implementations of the suite of [WOMBAT models](https://www.access-nri.org.au/models/model-components/biogeochemistry-model-component-ocean-wombat/) used in [ACCESS earth-system models](https://www.access-nri.org.au/models/).  



## WOMBAT_hy

- use FTorch
```Fortran
  use remin_ftorch, only: remin_ftorch_init, remin_ftorch_predict
```

- declare logicals to switch between normal, shadow and emulator mode
 ```Fortran
   logical            :: use_remin_emulator    = .false.
   logical            :: remin_emulator_shadow = .false.
   character(len=256) :: remin_emulator_path   = ''
 ```
- include subroutines to call NN at runtime  
  ```Fortran
  subroutine wombat_remin_init()
    logical :: file_exists
 
    if (remin_ready) return

    inquire(file=trim(remin_emulator_path), exist=file_exists)
    if(.not. file_exists) call mpp_error(FATAL, &
            'generic_WOMBAT_mid: emulator file not found: '//trim(remin_emulator_path))

    allocate(remin_x1(1, 4), remin_y1(1))
    remin_x1 = 1.0d0  ! dummy value
    remin_y1 = 0.0d0
 
    call torch_model_load(remin_model, trim(remin_emulator_path), torch_kCPU)
    call torch_tensor_from_array(remin_in(1), remin_x1, torch_kCPU)
    call torch_tensor_from_array(remin_out(1), remin_y1, torch_kCPU)
    remin_ready = .true.

  end subroutine wombat_remin_init
  ```
  ```Fortran  
  subroutine wombat_remin_point(temp, o2, detr, zoo, rate)
    real(kind=8), intent(in)   :: temp, o2, detr, zoo
    real(kind=8), intent(out)  :: rate
    type(ieee_flag_type), parameter :: trap_flags(3) = &
            [ieee_invalid, ieee_overflow, ieee_divide_by_zero]
    logical :: halting(3)

    remin_x1(1,1) = temp
    remin_x1(1,2) = o2
    remin_x1(1,3) = detr
    remin_x1(1,4) = zoo

    call ieee_get_halting_mode(trap_flags, halting)
    call ieee_set_halting_mode(trap_flags, .false.)
    call torch_model_forward(remin_model, remin_in, remin_out)
    call ieee_set_flag(trap_flags, .false.)
    call ieee_set_halting_mode(trap_flags, halting)

    rate = remin_y1(1)
  end subroutine wombat_remin_point
  ```

- replace remineralisation rate with NN

  ## Files to adjust
 
  1. **GFDLGTracersConfig.cmake.in**  
    - add FTorch dependency

  2.  **CMakeLists.txt**    
     - add FTorch and PyTorch paths (currently hard coded)  
     - add genericWOMBATlite_hy.F90 to target_sources   



