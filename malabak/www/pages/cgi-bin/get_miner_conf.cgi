echo
echo
if [ ! -f /config/cgminer.conf ] ; then
    cp /config/cgminer.conf.factory /config/cgminer.conf
fi
cat /config/cgminer.conf
