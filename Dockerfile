FROM ubuntu

MAINTAINER kurema

# https://qiita.com/Kashiwara/items/07e154bb5e859445eac6
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2

RUN apt-get update -y && \
    apt-get install -y tzdata
ENV TZ=Asia/Tokyo
RUN apt-get install -y ffmpeg && \
    apt-get install -y apache2 && \
    apt-get install -y cpanminus && \
    apt-get install -y build-essential && \
    apt-get install -y libexpat1-dev && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/*
RUN sed -ri 's/Options Indexes FollowSymLinks/Options Indexes FollowSymLinks ExecCGI/g;' /etc/apache2/apache2.conf && \
    echo "AddHandler cgi-script .cgi" >> /etc/apache2/apache2.conf && \
    a2enmod cgi.load && \
    echo "-- Apache2.conf --" && \
    cat /etc/apache2/apache2.conf

COPY nicoch/ /var/www/html/
RUN chmod 755 /var/www/html/*.cgi

#COPY config/ /etc/nicochcgi/
#RUN chown www-data:www-data /etc/nicochcgi/*

RUN cpanm --installdeps /var/www/html/

EXPOSE 80
CMD ["apachectl", "-D", "FOREGROUND"]

#Reference
#Run apache cgi on Docker (jp)
#https://senyoltw.hatenablog.jp/entry/2015/10/21/175847
#Enable cgi for apache (jp)
#http://blog.netandfield.com/shar/2017/01/apache2-cgi-debian-apt.html
#Docker in general (jp)
#https://qiita.com/kooohei/items/0e788a2ce8c30f9dba53
#owner of Docker -v (jp)
#https://qiita.com/yohm/items/047b2e68d008ebb0f001
#https://tech-blog.rakus.co.jp/entry/20200826/docker

#Note for Docker
#>docker run -p 82:80 -d nicoch

