# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8/nodejs-10
FROM registry.access.redhat.com/ubi8/nodejs-10:1-100 as runtime
USER 0
RUN yum update -y gnutls nodejs npm kernel-headers systemd && yum clean all && rm -rf /var/cache/yum && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages"
