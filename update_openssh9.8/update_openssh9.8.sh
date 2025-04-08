#!/bin/bash

#yum -y install gcc gcc-c++ pam-devel zlib-devel openssl-devel net-tools

tar -zxvf ./rpm/zlib-1.3.1.tar.gz -C /usr/local
cd /usr/local/zlib-1.3.1/
./configure
make -j 2 && make install
cd -

rpm -ivh pam-devel-1.1.8-23.el7.x86_64.rpm --nodeps --force

tar -zxvf ./rpm/openssl-1.1.1v.tar.gz -C /usr/local/
cd /usr/local/openssl-1.1.1v/

./config --prefix=/usr/local/openssl
make -j 2 && make install
ldd /usr/local/openssl/bin/openssl
echo "/usr/local/openssl/lib" >> /etc/ld.so.conf
ldconfig --verbose
ldd /usr/local/openssl/bin/openssl
which openssl
mv /bin/openssl /bin/openssl.old
ln -s /usr/local/openssl/bin/openssl /bin/openssl
openssl version
cd -
for i in $(rpm -qa | grep openssh);do rpm -e $i --nodeps;done
tar -zxvf ./rpm/openssh-9.8p1.tar.gz -C /usr/local/
cd /usr/local/openssh-9.8p1/
./configure --prefix=/usr/local/openssh --sysconfdir=/etc/ssh --with-pam --with-ssl-dir=/usr/local/openssl --with-md5-passwords --mandir=/usr/share/man --with-zlib=/usr/local/zlib --without-hardening
chmod 600 /etc/ssh/ssh_host_rsa_key
chmod 600 /etc/ssh/ssh_host_ecdsa_key
chmod 600 /etc/ssh/ssh_host_ed25519_key
make && make install
echo $?

cp contrib/redhat/sshd.init /etc/init.d/
cat /etc/init.d/sshd.init | grep SSHD
sed -i "s/SSHD=\/usr\/sbin\/sshd/SSHD=\/usr\/local\/openssh\/sbin\/sshd/g" /etc/init.d/sshd.init
cat /etc/init.d/sshd.init | grep SSHD

cat -n /etc/init.d/sshd.init | grep ssh-keygen
sed -i "s#/usr/bin/ssh-keygen -A#/usr/local/openssh/bin/ssh-keygen -A#g" /etc/init.d/sshd.init
cat -n /etc/init.d/sshd.init | grep ssh-keygen
echo 'X11Forwarding yes' >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
cp -arp /usr/local/openssh/bin/* /usr/bin/

/etc/init.d/sshd.init start

ssh -V
chmod +x /etc/rc.d/rc.local
echo "/etc/init.d/sshd.init start" >> /etc/rc.d/rc.local

#reboot
