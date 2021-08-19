FROM nvidia/cuda:11.0-devel-ubuntu20.04
WORKDIR /iGUARD
RUN apt-get update \
  && apt-get install -y wget bc gcc time gawk libtbb-dev
COPY . .
RUN make
