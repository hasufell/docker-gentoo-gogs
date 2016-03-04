FROM        mosaiksoftware/gentoo-amd64-paludis:latest
MAINTAINER  Julian Ospald <hasufell@gentoo.org>


RUN rm /etc/paludis/hooks/ebuild_preinst_pre/cleanup_files.bash

##### PACKAGE INSTALLATION #####

# need '-e world' since gogs is built manually and needs all headers
RUN chgrp paludisbuild /dev/tty && \
	git -C /usr/portage checkout -- . && \
	env-update && \
	source /etc/profile && \
	cave sync gentoo && \
	cave update-world -s docker-gogs && \
	cave resolve -e world -x --permit-old-version '*/*' && \
	cave fix-linkage -x && \
	rm -rf /usr/portage/* /srv/binhost/* \
		/usr/share/doc/* /usr/lib64/debug/* \
		/usr/share/man/* /usr/share/gtk-doc/* /usr/share/info/* \
		/usr/share/mime/* /usr/share/applications/* \
		/var/cache/paludis/names/* /var/cache/paludis/metadata/* \
		/var/tmp/paludis/*

# update etc files... hope this doesn't screw up
RUN etc-update --automode -5

################################


ENV GOPATH /gopath
ENV PATH $PATH:$GOROOT/bin:$GOPATH/bin

WORKDIR /gopath/src/github.com/gogits/gogs/
RUN git clone --depth=1 https://github.com/gogits/gogs.git \
	/gopath/src/github.com/gogits/gogs

# Build binary and clean up useless files
RUN go get -v -tags "sqlite redis memcache cert pam" && \
	go build -tags "sqlite redis memcache cert pam" && \
	mkdir /app/ && \
	mv /gopath/src/github.com/gogits/gogs/ /app/gogs/ && \
	rm -r "$GOPATH"


WORKDIR /app/gogs/

RUN useradd --shell /bin/bash --system --comment gogits git

# SSH login fix, otherwise user is kicked off after login
RUN echo "export VISIBLE=now" >> /etc/profile && \
	echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config

# Setup server keys on startup
RUN echo "HostKey /data/ssh/ssh_host_rsa_key" >> /etc/ssh/sshd_config && \
	echo "HostKey /data/ssh/ssh_host_dsa_key" >> /etc/ssh/sshd_config && \
	echo "HostKey /data/ssh/ssh_host_ed25519_key" >> /etc/ssh/sshd_config

# Prepare data
ENV GOGS_CUSTOM /data/gogs
RUN echo "export GOGS_CUSTOM=/data/gogs" >> /etc/profile

RUN chown -R redis /var/log/redis

COPY setup.sh /setup.sh
RUN chmod +x /setup.sh
COPY config/supervisord.conf /etc/supervisord.conf

EXPOSE 3000

CMD /setup.sh && exec /usr/bin/supervisord -n -c /etc/supervisord.conf
