
# GFDL generic tracers - **Development branch for WOMBAT-hy**

This fork is to experiment on the implementation of FTorch within WOMBAT, it contains the model code and a description of the changes made to call a Torchscript at runtime.  
See *https://github.com/oetjensa/WOMBAT_hybrid* for more details about the experiment configuration.  

This is a fork of the [NOAA-GFDL/ocean_BGC](https://github.com/NOAA-GFDL/ocean_BGC) repo managed by NOAA-GFDL. It contains a collection of tracers and associated code for use with the MOM and GOLD ocean models.  

This fork includes generic tracer implementations of the suite of [WOMBAT models](https://www.access-nri.org.au/models/model-components/biogeochemistry-model-component-ocean-wombat/) used in [ACCESS earth-system models](https://www.access-nri.org.au/models/).  



## generic_WOMBATlite_hy

*this will be updated once code development is finalised*

1. use FTorch  
2. declare logicals to switch between normal, shadow and emulator mode  
3. include subroutines to call NN at runtime  
4. replace remineralisation rate with emulator, call emulator in batches
   

## Other files to edit
 
1. **GFDLGTracersConfig.cmake.in**  
    - added FTorch dependency

2.  **CMakeLists.txt**    
     - added FTorch and PyTorch paths (currently hard coded)   
     - added genericWOMBATlite_hy.F90 to target_sources  
 
3. **generic_tracers, generic_tracers_utils**  
    - added generic_WOMBATlite_hy  



