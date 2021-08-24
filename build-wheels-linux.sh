#!/bin/bash

# Based off of https://colmap.github.io/install.html (COLMAP)
# and https://github.com/mihaidusmanu/pycolmap#getting-started (pycolmap)
# and http://ceres-solver.org/installation.html (Ceres)

# declare -a PYTHON_VERSION=( $1 )

# we cannot simply use `pip` or `python`, since points to old 2.7 version
PYBIN="/opt/python/$PYTHON_VERSION/bin"
PYVER_NUM=$($PYBIN/python -c "import sys;print(sys.version.split(\" \")[0])")
PYTHONVER="$(basename $(dirname $PYBIN))"

echo "Python bin path: $PYBIN"
echo "Python version number: $PYVER_NUM"
echo "Python version: $PYTHONVER"

export PATH=$PYBIN:$PATH

${PYBIN}/pip install auditwheel

PYTHON_EXECUTABLE=${PYBIN}/python
# We use distutils to get the include directory and the library path directly from the selected interpreter
# We provide these variables to CMake to hint what Python development files we wish to use in the build.
PYTHON_INCLUDE_DIR=$(${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
PYTHON_LIBRARY=$(${PYTHON_EXECUTABLE} -c "import distutils.sysconfig as sysconfig; print(sysconfig.get_config_var('LIBDIR'))")


CURRDIR=$(pwd)
COLMAP_BRANCH="dev"

echo "Num. processes to use for building: ${nproc}"

apt-get update

# ----------- Install dependencies from the default Ubuntu repositories -----------------
yum install \
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
yum install libcgal-qt5-dev

yum -y install wget
wget https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz
tar -xvzf eigen-3.4.0.tar.gz

echo "CMAKE_PREFIX_PATH -> $CMAKE_PREFIX_PATH"
export CMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH:`pwd`/eigen-3.4.0"
echo "CMAKE_PREFIX_PATH -> $CMAKE_PREFIX_PATH"

ls -ltrh $CMAKE_PREFIX_PATH

# ----------- Install CERES solver -------------------------------------------------------
yum install libeigen3-dev # was not in COLMAP instructions
yum install libatlas-base-dev libsuitesparse-dev
yum install libgoogle-glog-dev libgflags-dev # was not in COLMAP instructions
git clone https://ceres-solver.googlesource.com/ceres-solver
cd ceres-solver
git checkout $(git describe --tags) # Checkout the latest release
mkdir build
cd build
cmake .. -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH
make -j$(nproc)
make install

cd $CURRDIR
# ---------------- Clone COLMAP ----------------------------------------------------------
git clone https://github.com/colmap/colmap.git
cd colmap
git checkout dev

# Set the build directory
# BUILDDIR="/io/colmap_build"
# mkdir $BUILDDIR
# cd $BUILDDIR


echo ""
echo "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}"
echo "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}"
echo "PYTHON_LIBRARY:${PYTHON_LIBRARY}"
echo ""

# ---------- Fix broken dependencies -----

# try new boost install
yum install libboost-all-dev
yum install git
yum install cmake
yum install build-essential
yum install libboost-program-options-dev
yum install libboost-filesystem-dev
yum install libboost-graph-dev
yum install libboost-system-dev
yum install libboost-test-dev
yum install libeigen3-dev
yum install libsuitesparse-dev
yum install libfreeimage-dev
yum install libgoogle-glog-dev
yum install libgflags-dev
yum install libglew-dev
yum install qtbase5-dev
yum install libqt5opengl5-dev
yum install libcgal-dev
yum install libcgal-qt5-dev


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

make -j$(nproc) install

mkdir -p /io/wheelhouse

# ----------- Build pycolmap wheel -----------------------------------------------------
cd $CURRDIR
git clone --recursive https://github.com/mihaidusmanu/pycolmap.git
cd pycolmap
PLAT=manylinux2014_x86_64
#"${PYBIN}/python" setup.py bdist_wheel --python-tag=$PYTHONVER --plat-name=$PLAT
"${PYBIN}/python" setup.py bdist_wheel --plat-name=$PLAT #--python-tag=$PYTHONVER 

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
