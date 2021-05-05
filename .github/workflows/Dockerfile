FROM ubuntu:devel AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  git \
  gcc \
  g++ \
  make \
  cmake \
  autoconf \
  automake \
  libtool \
  curl \
  xz-utils

RUN curl -O https://nim-lang.org/download/nim-1.2.12.tar.xz; tar xf nim-1.2.12.tar.xz; mv nim-1.2.12 nim
RUN cd nim; sh build.sh; ln -s `pwd`/bin/nim /bin/nim
RUN cd nim; nim c koch; ./koch tools; ln -s `pwd`/bin/nimble /bin/nimble

COPY . ./
RUN nimble build -y -d:nogui

FROM ubuntu:devel
COPY --from=builder ./build/Meros .
ENTRYPOINT ["./Meros"]
