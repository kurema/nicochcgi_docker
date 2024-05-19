FROM ubuntu

MAINTAINER kurema

# https://qiita.com/Kashiwara/items/07e154bb5e859445eac6
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2

#You need to install tzdata first to prevent 'Please select the geographic area...' message.
#https://sleepless-se.net/2018/07/31/docker-build-tzdata-ubuntu/
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends tzdata

#Timezone is set to Japan assuming you are in Japan.
ENV TZ=Asia/Tokyo
#Install dependencies.
RUN apt-get install -y --no-install-recommends ffmpeg \
      apache2 \
      cpanminus \
      build-essential \
      libexpat1-dev \
#fix cpanm error...
      liblwp-protocol-https-perl \
      libnet-ssleay-perl \
      libcrypt-ssleay-perl \
      openssl \
      libssl-dev && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/*
#Enable cgi. This is cgi in 2020.
RUN sed -ri 's/Options Indexes FollowSymLinks/Options Indexes FollowSymLinks ExecCGI/g;' /etc/apache2/apache2.conf && \
    echo "AddHandler cgi-script .cgi" >> /etc/apache2/apache2.conf && \
    a2enmod cgid && \
    echo "-- Apache2.conf --" && \
    cat /etc/apache2/apache2.conf

#Copy cpanfile first for better cache management.
RUN touch /var/www/html/cpanfile
COPY nicoch/cpanfile /var/www/html/cpanfile
RUN cpanm --installdeps --no-man-pages --verbose /var/www/html/ && \
    rm -rf /root/.cpanm/work/*

RUN mkdir -p ${APACHE_RUN_DIR} && touch ${APACHE_RUN_DIR}/dummy

COPY nicoch/ /var/www/html/
RUN chmod 755 /var/www/html/*.cgi /var/www/html/*.pl

#/etc/nicochcgi/ should be overwritten using -v
COPY config/ /etc/nicochcgi/
RUN chown www-data:www-data /etc/nicochcgi/*
RUN chmod 666 /etc/nicochcgi/*

#I think document should be included.
COPY README.md /

RUN echo "#/bin/sh\nrm -f /var/run/apache2/cgisock.*\napachectl -D FOREGROUND" > /startup.sh && \
    chmod 777 /startup.sh

EXPOSE 80
#CMD ["apachectl", "-D", "FOREGROUND"]
CMD ["sh", "-c", "/startup.sh"]

#Reference
#Docker! (jp)
#https://tech-lab.sios.jp/archives/18811
#Run apache cgi on Docker (jp)
#https://senyoltw.hatenablog.jp/entry/2015/10/21/175847
#Enable cgi for apache (jp)
#http://blog.netandfield.com/shar/2017/01/apache2-cgi-debian-apt.html
#Docker in general (jp)
#https://qiita.com/kooohei/items/0e788a2ce8c30f9dba53
#owner of Docker -v (jp)
#https://qiita.com/yohm/items/047b2e68d008ebb0f001
#https://tech-blog.rakus.co.jp/entry/20200826/docker
#Docker+Cron (jp)
#https://qiita.com/YuukiMiyoshi/items/bb7f14436d60d4bd8a8b
#Docker+GitHub Actions+GitHub Package Registry (jp)
#https://qiita.com/homines22/items/6d28461d97906e42f57c

#Note for Docker
#>docker run -p 82:80 -d nicochcgi
#>docker build -t nicochcgi .
