FROM ubuntu

RUN apt-get update -y && \
    apt-get install -y tzdata
ENV TZ=Asia/Tokyo
RUN apt-get install -y ffmpeg && \
    apt-get install -y apache2 && \
    apt-get install -y cpanminus && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/*
