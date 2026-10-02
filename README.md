# GFDL generic tracers

This is a fork of the [NOAA-GFDL/ocean_BGC](https://github.com/NOAA-GFDL/ocean_BGC) repo managed by NOAA-GFDL. It contains a collection of tracers and associated code for use with the MOM and GOLD ocean models.

This fork includes generic tracer implementations of the suite of [WOMBAT models](https://www.access-nri.org.au/models/model-components/biogeochemistry-model-component-ocean-wombat/) used in [ACCESS earth-system models](https://www.access-nri.org.au/models/).


**This is the development branch for WOMBAT-hy**


# TEST 1: Emulator shadow

run emulator and bacteria in parallel





# Setup PyTorch and FTorch on GADI

## PyTorch

cd ftorch_model                      # create folder  \
module purge
module load python3/3.11.7           # load new python version \
python3 -m venv torchvenv            # create virtual environment \
source torchvenv/bin/activate        \
pip install --upgrade pip            # update pip 

 install torch and torchvision, check for version: \
 https://pytorch.org/get-started/locally/ 

pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu

## FTorch
https://cambridge-iccs.github.io/FTorch/page/usage/generic_example.html

 load same compilers used for WOMBAT (ftx) \
module load intel-compiler-llvm/2025.2.0 gcc/12.2.0 cmake   
         
git clone https://github.com/Cambridge-ICCS/FTorch.git FTorch \
mkdir build \ 
cd build 

 cmake build : 

 https://cambridge-iccs.github.io/FTorch/page/installation/general.html \
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_Fortran_COMPILER=ifx -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_PREFIX_PATH=$(python -c "import torch; print(torch.utils.cmake_prefix_path)") -DCMAKE_INSTALL_PREFIX=$(cd ../.. && pwd)/FTorch_install -Wno-dev

cmake --build . \
cmake --install . 

 location of config file: \
find ../../FTorch_install -name FTorchConfig.cmake 


## Train model using PyTorch

link to Jupyter notebook

## Export TorchScript

link Jupyter notebook, Python scripts \
remin_emulator_ts.pt \
cp /g/data/jk72/ao2582/PyTorch/remin_emulator_ts.pt . 


### Test run
 fresh console, copy all files to test directory 
 
 export DEPS=/g/data/jk72/ao2582/ACCESS/wombat_dev/ACCESS-OM3/ftorch_model 

cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_Fortran_COMPILER=ifx -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_PREFIX_PATH="$DEPS/FTorch_install;$(python -c 'import torch; print(torch.utils.cmake_prefix_path)')" -DFTorch_DIR=$DEPS/FTorch_install/lib64/cmake/FTorch -Wno-dev \

make VERBOSE=1 2>&1 | tee build_log.txt \

./build/standin_wombat 

## Adjust CMakefile in gtracers 
hard code paths to torch, ftorch 

## Changes for Runtime

 Input: set logicals, path to .pt \
 config file: Update EXE


