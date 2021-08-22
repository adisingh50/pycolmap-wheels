#!/bin/bash

# Based off of https://colmap.github.io/install.html (COLMAP)
# and https://github.com/mihaidusmanu/pycolmap#getting-started (pycolmap)
# and http://ceres-solver.org/installation.html (Ceres)

CURRDIR=$(pwd)
GTSAM_BRANCH="develop"

echo "Num. processes to use for building: ${nproc}"

# ----------- Install dependencies from the default Ubuntu repositories -----------------
sudo apt-get install \
    git \
    cmake \
    build-essential \
    libboost-program-options-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-system-dev \
    libboost-test-dev \
    libeigen3-dev \
    libsuitesparse-dev \
    libfreeimage-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libglew-dev \
    qtbase5-dev \
    libqt5opengl5-dev \
    libcgal-dev
sudo apt-get install libcgal-qt5-dev

# ----------- Install CERES solver -------------------------------------------------------
sudo apt install libeigen3-dev # was not in COLMAP instructions
sudo apt-get install libatlas-base-dev libsuitesparse-dev
sudo apt-get install libgoogle-glog-dev libgflags-dev # was not in COLMAP instructions
git clone https://ceres-solver.googlesource.com/ceres-solver
cd ceres-solver
git checkout $(git describe --tags) # Checkout the latest release
mkdir build
cd build
cmake .. -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF
make -j$(nproc)
sudo make install

cd $CURRDIR
# ---------------- Clone COLMAP ----------------------------------------------------------
git clone https://github.com/colmap/colmap.git
cd colmap
git checkout dev

# Set the build directory
# BUILDDIR="/io/colmap_build"
# mkdir $BUILDDIR
# cd $BUILDDIR

PYBIN="/opt/python/$PYTHON_VERSION/bin"
PYVER_NUM=$($PYBIN/python -c "import sys;print(sys.version.split(\" \")[0])")
PYTHONVER="$(basename $(dirname $PYBIN))"

export PATH=$PYBIN:$PATH

PYTHON_EXECUTABLE=${PYBIN}/python
# We use distutils to get the include directory and the library path directly from the selected interpreter
# We provide these variables to CMake to hint what Python development files we wish to use in the build.
PYTHON_INCLUDE_DIR=$(${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
PYTHON_LIBRARY=$(${PYTHON_EXECUTABLE} -c "import distutils.sysconfig as sysconfig; print(sysconfig.get_config_var('LIBDIR'))")

echo ""
echo "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}"
echo "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}"
echo "PYTHON_LIBRARY:${PYTHON_LIBRARY}"
echo ""

# ---------- Fix broken dependencies -----

# try new boost install
sudo apt-get install libboost-all-dev
sudo apt-get install git
sudo apt-get install cmake
sudo apt-get install build-essential
sudo apt-get install libboost-program-options-dev
sudo apt-get install libboost-filesystem-dev
sudo apt-get install libboost-graph-dev
sudo apt-get install libboost-system-dev
sudo apt-get install libboost-test-dev
sudo apt-get install libeigen3-dev
sudo apt-get install libsuitesparse-dev
sudo apt-get install libfreeimage-dev
sudo apt-get install libgoogle-glog-dev
sudo apt-get install libgflags-dev
sudo apt-get install libglew-dev
sudo apt-get install qtbase5-dev
sudo apt-get install libqt5opengl5-dev
sudo apt-get install libcgal-dev
sudo apt-get install libcgal-qt5-dev


# ----------- Build COLMAP ------------------------------------------------------------
cd $CURRDIR
BUILDDIR=$CURRDIR/colmap/colmap_build
mkdir -p $BUILDDIR
cd $BUILDDIR
cmake .. -DCMAKE_BUILD_TYPE=Release 

if [ $ec -ne 0 ]; then
    echo "Error:"
    cat ./CMakeCache.txt
    exit $ec
fi
set -e -x

sudo make -j$(nproc) install

mkdir -p /io/wheelhouse

# ----------- Build pycolmap wheel -----------------------------------------------------
cd $CURRDIR
git clone --recursive https://github.com/mihaidusmanu/pycolmap.git
cd pycolmap
"${PYBIN}/python" setup.py bdist_wheel --python-tag=$PYTHONVER --plat-name=$PLAT

cp ./dist/*.whl /io/wheelhouse/

# Bundle external shared libraries into the wheels
for whl in ./dist/*.whl; do
    auditwheel repair "$whl" -w /io/wheelhouse/
done

for whl in /io/wheelhouse/*.whl; do
    new_filename=$(echo $whl | sed "s#\.none-manylinux2014_x86_64\.#.#g")
    new_filename=$(echo $new_filename | sed "s#\.manylinux2014_x86_64\.#.#g") # For 37 and 38
    new_filename=$(echo $new_filename | sed "s#-none-#-#g")
    mv $whl $new_filename
done
