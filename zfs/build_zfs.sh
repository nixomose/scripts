cd /root/zfs/spl
make distclean
./autogen.sh && ./configure && make
make install

cd /root/zfs/zfs
make distclean
./autogen.sh && ./configure && make
make install

depmod -a
