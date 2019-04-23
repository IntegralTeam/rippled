FROM ubuntu:18.04 AS builder

RUN apt update
RUN apt install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  cmake \
  doxygen \
  git \
  libprotobuf-dev \
  libssl-dev \
  protobuf-compiler \
  wget

RUN wget -O- https://dl.bintray.com/boostorg/release/1.67.0/source/boost_1_67_0.tar.gz | tar xz
WORKDIR /boost_1_67_0
RUN ./bootstrap.sh --with-libraries=atomic,chrono,context,coroutine,date_time,filesystem,program_options,regex,serialization,system,thread
RUN ./b2 install link=shared,static -j$(nproc)

COPY . /rippled
WORKDIR /build
RUN cmake -DCMAKE_BUILD_TYPE=Release ../rippled
RUN make -j$(nproc)
RUN strip rippled


FROM ubuntu:18.04

RUN apt update \
  && apt install -y --no-install-recommends \
    protobuf-compiler \
    libssl1.1 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/libboost_* /usr/local/lib/
COPY --from=builder /build/rippled /usr/local/bin/

RUN groupadd --gid 1000 rippled \
  && useradd --uid 1000 --gid rippled --shell /bin/bash --create-home rippled

RUN mkdir -p /var/lib/rippled && chown -R rippled /var/lib/rippled

USER rippled

RUN mkdir -p /home/rippled/.config/ripple

COPY --from=builder /rippled/cfg/rippled-example.cfg /home/rippled/.config/ripple/rippled.cfg
COPY --from=builder /rippled/cfg/validators-example.txt /home/rippled/.config/ripple/validators.txt

# P2P && RPC
EXPOSE 51235 5005

CMD rippled
