FROM nvidia/cuda:8.0-devel-ubuntu14.04

RUN echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list
RUN apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-key 421C365BD9FF1F717815A3895523BAEEB01FA116
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-indigo-desktop-full \
        python-rosinstall \
        libgoogle-glog-dev \
        libatlas-base-dev \
        libeigen3-dev \
        libsuitesparse-dev \
        ninja-build \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSLO http://ceres-solver.org/ceres-solver-1.12.0.tar.gz \
    && tar zxf ceres-solver-1.12.0.tar.gz \
    && cd ceres-solver-1.12.0 \
    && cmake -G Ninja -D CMAKE_BUILD_TYPE=Release . \
    && ninja \
    && ninja install \
    && cd .. \
    && rm -rf ceres-solver-1.12.0

# build OpenCV manually to get CUDA support
RUN curl -sSLO https://github.com/opencv/opencv/archive/2.4.8.tar.gz \
    && tar zxf 2.4.8.tar.gz \
    && curl -sSL https://github.com/opencv/opencv/commit/60a5ada4541e777bd2ad3fe0322180706351e58b.patch | patch -d opencv-2.4.8 -p1 \
    && curl -sSL https://github.com/opencv/opencv/commit/10896129b39655e19e4e7c529153cb5c2191a1db.patch | patch -d opencv-2.4.8/modules/gpu -p3 \
    && cd opencv-2.4.8 \
    && cmake -G Ninja -D CMAKE_BUILD_TYPE=Release -D CUDA_GENERATION=Kepler . \
    && ninja \
    && ninja install \
    && cd .. \
    && rm -rf opencv-2.4.8
ENV CMAKE_PREFIX_PATH=/usr/local:$CMAKE_PREFIX_PATH

# OpenChisel's requirement
RUN curl -sSLO https://github.com/PointCloudLibrary/pcl/archive/pcl-1.8.0.tar.gz \
    && tar zxf pcl-1.8.0.tar.gz \
    && cd pcl-pcl-1.8.0 \
    && sed -i -- 's/SET(CMAKE_CXX_FLAGS "-Wall/SET(CMAKE_CXX_FLAGS "-std=c++11 -Wall/g' CMakeLists.txt \
    && cmake -G Ninja -D CMAKE_BUILD_TYPE=Release . \
    && ninja \
    && ninja install \
    && cd .. \
    && rm -rf pcl-pcl-1.8.0

RUN mkdir -p /catkin_ws/src
WORKDIR /catkin_ws/src
# OpenChisel's requirement
RUN curl -sSLO https://github.com/ros-perception/perception_pcl/archive/indigo-devel.tar.gz \
    && tar zxf indigo-devel.tar.gz \
    && rm indigo-devel.tar.gz \
    && cd perception_pcl-indigo-devel \
    && sed -i -- 's/find_package(PCL REQUIRED)/find_package(PCL 1.8 REQUIRED)/g' pcl_ros/CMakeLists.txt \
    && cd ..

WORKDIR /catkin_ws
RUN /bin/bash -c "source /opt/ros/indigo/setup.bash && catkin_make --use-ninja"

RUN mkdir -p /catkin_ws/src/VI-MEAN
COPY . /catkin_ws/src/VI-MEAN

RUN /bin/bash -c "source /opt/ros/indigo/setup.bash && catkin_make --use-ninja"

# To run a sample.bag:
# xhost +local:root
# sudo nvidia-docker run -it --rm --volume=`pwd`:/src --env="DISPLAY" --env="QT_X11_NO_MITSHM=1" --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" $IMAGE_HASH bash
# source /opt/ros/indigo/setup.bash
# source /catkin_ws/devel/setup.bash
# roslaunch stereo_mapper sample_all.launch &
# rosbag play /src/sample.bag
#
# Ref:
# http://wiki.ros.org/docker/Tutorials/GUI