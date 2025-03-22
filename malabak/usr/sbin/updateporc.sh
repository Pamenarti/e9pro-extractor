#!/bin/sh

function checkCtrlboardType() {
    res=$(grep "Zynq7020" $1)
    if [ "$res" != "" ]; then
        return 0
    else
        return 9
    fi
}

pemSel=/etc/bitmain.pub
function spliteFile(){
    if [ -d /tmp/tmpfw ]; then
        rm /tmp/tmpfw -rf
    fi
    mkdir -p /tmp/tmpfw
    /usr/bin/FileParser -s S19 $1 ${pemSel}
    res=$?
    if [ $res -ne 0 ]; then
        echo "BMU CHECK FAILED!"
    fi
    return $res
}

function checkFile(){
    cd /tmp/tmpfw
    if [ ! -f miner.pem ]; then
        echo "Cannot Find Miner!"
        return 1
    fi
    if [ ! -f miner.pem.sig ]; then
        echo "Cannot Find Miner Signature"
        return 2
    fi
    openssl dgst -sha256 -verify ${pemSel} -signature miner.pem.sig miner.pem > /dev/null
    res=$?
    if [ $res -ne 0 ]; then
        echo "Check Miner Signature Failed!"
        return 3
    fi

    srcFile="BOOT.bin devicetree.dtb uImage minerfs.image.gz update.image.gz crl.tar.gz miner.btm.tar.gz datafile"
    for file in ${srcFile};
    do
        sigFile="${file}.sig"
        if [ -f ${file} ]; then
            if [ ! -f ${sigFile} ]; then
                echo "Cannot Find ${sigFile} !"
                return 1
            else
                openssl dgst -sha256 -verify miner.pem -signature ${sigFile} ${file}  > /dev/null
                res=$?
                if [ $res -ne 0 ]; then
                    echo "Check ${file} Signature Failed!"
                    return 2
                fi
            fi
        fi
    done
}

function writeToNand(){
    cd /tmp/tmpfw/

    if [ -f datafile ]; then
        echo "write image.ub to mtd1"
        flash_erase /dev/mtd1 0 0 >/dev/null
        nandwrite -p -s 0x0 /dev/mtd1 datafile >/dev/null
    fi

    sleep 3
    sync
    echo "----------write all update files over---------------"
}


srcFile=$1

# Split Update File
if [ -z ${srcFile} ]; then
	echo "Wrong Param"
	return 9
fi

checkCtrlboardType ${srcFile}
res=$?
if [ $res -ne 0 ]; then
	echo "Bmu is not for Zynq2020! res=$res"
	return $res
fi

spliteFile ${srcFile}
res=$?
if [ $res -ne 0 ]; then
	echo "Splite Bmu Failed! res=$res"
	return $res
fi

#Check Splited Data
checkFile
res=$?
if [ $res -ne 0 ]; then
    echo "Check Data Failed! res=$res"
    return $res
fi

# check version
version_fw=$(cat /usr/bin/fw_version)
version_isolate=$(cat /usr/bin/isolate_time)

if [[ ${version_fw:0:1} != "2" ]] || [[ ${version_isolate:0:1} != "2" ]]; then
    echo "Both strings must start with the character '2'"
    return 1
fi

if [ "$version_fw" -gt "$version_isolate" ]; then
    echo "Right firmware version\n"
else
    echo "Illegal firmware version! version_fw:$version_fw version_isolate:$version_isolate\n"
    return 1
fi

#Write datafile(image.ub)  To Nand
writeToNand
if [ $res -ne 0 ]; then
    return $res
fi
