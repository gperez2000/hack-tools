#!/bin/bash
#set -x

SUDO=sudo
#SUDO='echo #'
#SUDO=nothing

# certain kexts are exceptions to automatic installation
STANDARD_EXCEPTIONS="Sensors|FakePCIID|BrcmPatchRAM|BrcNonPatchRAM|BrcmBluetoothInjector|BrcmFirmwareData|IntelBacklight|WhateverName"
if [[ "$EXCEPTIONS" == "" ]]; then
    EXCEPTIONS="$STANDARD_EXCEPTIONS"
else
    EXCEPTIONS="$STANDARD_EXCEPTIONS|$EXCEPTIONS"
fi

# standard essential kexts
# these kexts are only updated if installed
ESSENTIAL="FakeSMC.kext RealtekRTL8111.kext IntelMausiEthernet.kext USBInjectAll.kext Lilu.kext WhateverGreen.kext AppleBacklightInjector.kext IntelBacklight.kext VoodooPS2Controller.kext FakePCIID.kext FakePCIID_XHCIMux.kext $ESSENTIAL"

TAGCMD="$(dirname ${BASH_SOURCE[0]})"/tag
TAG=tag_file
SLE=/System/Library/Extensions
LE=/Library/Extensions

# extract minor version (eg. 10.9 vs. 10.10 vs. 10.11)
MINOR_VER=$([[ "$(sw_vers -productVersion)" =~ [0-9]+\.([0-9]+) ]] && echo ${BASH_REMATCH[1]})

# install to /Library/Extensions for 10.11 or greater
if [[ $MINOR_VER -ge 11 ]]; then
    KEXTDEST=$LE
else
    KEXTDEST=$SLE
fi

# this could be removed if 'tag' can be made to work on old systems
function tag_file
{
    if [[ $MINOR_VER -ge 9 ]]; then
        $SUDO "$TAGCMD" "$@"
    fi
}

function check_directory
{
    for x in $1; do
        if [ -e "$x" ]; then
            return 1
        else
            return 0
        fi
    done
}

function nothing
{
    :
}

function remove_kext
{
    $SUDO rm -Rf $SLE/"$1" $LE/"$1"
}

function install_kext
{
    if [ "$1" != "" ]; then
        echo installing $1 to $KEXTDEST
        remove_kext `basename $1`
        $SUDO cp -Rf $1 $KEXTDEST
        $TAG -a Gray $KEXTDEST/`basename $1`
    fi
}

function install_app
{
    if [ "$1" != "" ]; then
        echo installing $1 to /Applications
        $SUDO rm -Rf /Applications/`basename $1`
        cp -Rf $1 /Applications
        $TAG -a Gray /Applications/`basename $1`
    fi
}

function install_binary
{
    if [ "$1" != "" ]; then
        if [[ ! -e /usr/local/bin ]]; then $SUDO mkdir /usr/local/bin; fi
        echo installing $1 to /usr/local/bin
        $SUDO rm -f /usr/bin/`basename $1` /usr/local/bin/`basename $1`
        $SUDO cp -f $1 /usr/local/bin
        $TAG -a Gray /usr/local/bin/`basename $1`
    fi
}

function install
{
    local installed=0
    out=${1/.zip/}
    rm -Rf $out/* && unzip -q -d $out $1
    check_directory $out/Release/*.kext
    if [ $? -ne 0 ]; then
        for kext in $out/Release/*.kext; do
            # install the kext when it exists regardless of filter
            kextname="`basename $kext`"

            if [[ -e "$SLE/$kextname" || -e "$KEXTDEST/$kextname" || "$2" == "" || "`echo $kextname | grep -vE "$2"`" != "" ]]; then
                install_kext $kext
            fi
        done
        installed=1
    fi
    check_directory $out/*.kext
    if [ $? -ne 0 ]; then
        for kext in $out/*.kext; do
            # install the kext when it exists regardless of filter
            kextname="`basename $kext`"
            if [[ -e "$SLE/$kextname" || -e "$KEXTDEST/$kextname" || "$2" == "" || "`echo $kextname | grep -vE "$2"`" != "" ]]; then
                install_kext $kext
            fi
        done
        installed=1
    fi
    check_directory $out/Release/*.app
    if [ $? -ne 0 ]; then
        for app in $out/Release/*.app; do
            # install the app when it exists regardless of filter
            appname="`basename $app`"
            if [[ -e "/Applications/$appname" || -e "/Applications/$appname" || "$2" == "" || "`echo $appname | grep -vE "$2"`" != "" ]]; then
                install_app $app
            fi
        done
        installed=1
    fi
    check_directory $out/*.app
    if [ $? -ne 0 ]; then
        for app in $out/*.app; do
            # install the app when it exists regardless of filter
            appname="`basename $app`"
            if [[ -e "/Applications/$appname" || -e "/Applications/$appname" || "$2" == "" || "`echo $appname | grep -vE "$2"`" != "" ]]; then
                install_app $app
            fi
        done
        installed=1
    fi
    if [ $installed -eq 0 ]; then
        check_directory $out/*
        if [ $? -ne 0 ]; then
            for tool in $out/*; do
                install_binary $tool
            done
        fi
    fi
}

function warn_about_superuser
{
    if [ "$(id -u)" != "0" ]; then
        echo "This script requires superuser access..."
    fi
}

function install_tools
{
    # unzip/install tools
    check_directory _downloads/tools/*.zip
    if [ $? -ne 0 ]; then
        echo Installing tools...
        for tool in _downloads/tools/*.zip; do
            install $tool
        done
    fi
}

function install_download_kexts
{
    # unzip/install kexts
    check_directory _downloads/kexts/*.zip
    if [ $? -ne 0 ]; then
        echo Installing kexts...
        for kext in _downloads/kexts/*.zip; do
            install $kext "$EXCEPTIONS"
        done
    fi
}

function install_brcmpatchram_kexts
{
    if [[ $MINOR_VER -ge 11 ]]; then
        # 10.11 needs BrcmPatchRAM2.kext
        install_kext _downloads/kexts/RehabMan-BrcmPatchRAM*/Release/BrcmPatchRAM2.kext
        install_kext _downloads/kexts/RehabMan-BrcmPatchRAM*/Release/BrcmNonPatchRAM2.kext
        # remove BrcPatchRAM.kext/etc just in case
        remove_kext BrcmPatchRAM.kext
        remove_kext BrcmNonPatchRAM.kext
    else
        # prior to 10.11, need BrcmPatchRAM.kext
        install_kext _downloads/kexts/RehabMan-BrcmPatchRAM*/Release/BrcmPatchRAM.kext
        install_kext _downloads/kexts/RehabMan-BrcmPatchRAM*/Release/BrcmNonPatchRAM.kext
        # remove BrcPatchRAM2.kext/etc just in case
        remove_kext BrcmPatchRAM2.kext
        remove_kext BrcmNonPatchRAM2.kext
    fi
    # this guide does not use BrcmBluetoothInjector.kext/BrcmFirmwareData.kext
    remove_kext BrcmBluetoothInjector.kext
    remove_kext BrcmFirmwareData.kext
}

function install_fakepciid_intel_hdmi_audio
{
    install_kext _downloads/kexts/RehabMan-FakePCIID*/Release/FakePCIID.kext
    install_kext _downloads/kexts/RehabMan-FakePCIID*/Release/FakePCIID_Intel_HDMI_Audio.kext
}

function install_fakepciid_xhcimux
{
    install_kext _downloads/kexts/RehabMan-FakePCIID*/Release/FakePCIID.kext
    install_kext _downloads/kexts/RehabMan-FakePCIID*/Release/FakePCIID_XHCIMux.kext
}

function remove_deprecated_kexts
{
    # now using IntelBacklight.kext instead of ACPIBacklight.kext
    remove_kext ACPIBacklight.kext
    # deal with some renames
    remove_kext FakePCIID_BCM94352Z_as_BCM94360CS2.kext
    remove_kext FakePCIID_HD4600_HD4400.kext
    # IntelGraphicsFixup.kext is no longer used (replaced by WhateverGreen.kext)
    remove_kext IntelGraphicsFixup.kext
    # CoreDisplayFixup uses WhateverGreen.kext (-cdfon)
    remove_kext CoreDisplayFixup.kext
    # FakePCIID_Intel_HD_Graphics.kext not needed either
    remove_kext FakePCIID_Intel_HD_Graphics.kext
    # using AirportBrcmFixup.kext instead of FakePCIID_Broadcom_WiFi.kext
    remove_kext FakePCIID_Broadcom_WiFi.kext
}

function install_backlight_kexts
{
    # install AppleBacklightInjector.kext on 10.12
    #  (set BKLT=1 in SSDT-HACK.dsl to use it, set BKLT=0 to use IntelBacklight.kext)
    if [[ $MINOR_VER -ge 12 ]]; then
        install_kext kexts/AppleBacklightInjector.kext
        remove_kext IntelBacklight.kext
    else
        install_kext _downloads/kexts/RehabMan-IntelBacklight*/Release/IntelBacklight.kext
        remove_kext AppleBacklightInjector.kext
    fi
}

function install_fakesmc_sensor_kexts
{
    install_kext _downloads/kexts/RehabMan-FakeSMC*/FakeSMC_ACPISensors.kext
    install_kext _downloads/kexts/RehabMan-FakeSMC*/FakeSMC_CPUSensors.kext
    install_kext _downloads/kexts/RehabMan-FakeSMC*/FakeSMC_GPUSensors.kext
    install_kext _downloads/kexts/RehabMan-FakeSMC*/FakeSMC_LPCSensors.kext
    install_kext _downloads/kexts/RehabMan-FakeSMC*/FakeSMC_SMMSensors.kext
}

function remove_hdamods
{
    if [[ "$HDA" != "" ]]; then
        remove_kext AppleHDA_$HDA.kext
        remove_kext AppleHDAHCD_$HDA.kext
        $SUDO rm -f $SLE/AppleHDA.kext/Contents/Resources/*.zml*
    fi
}

function install_hdazml
{
    if [[ "$HDA" != "" ]]; then
        remove_hdamods
        # alternate configuration (requires .xml.zlib .zml.zlib AppleHDA patch)
        "$(dirname ${BASH_SOURCE[0]})"/patch_hdazml.sh "$HDA"
        $SUDO cp AppleHDA_${HDA}_Resources/*.zml* $SLE/AppleHDA.kext/Contents/Resources
        $TAG -a Gray $SLE/AppleHDA.kext
    fi
}

function install_hdainject
{
    if [[ "$HDA" != "" ]]; then
        remove_hdamods
        # HDA injector configuration
        remove_kext AppleHDA_$HDA.kext
        "$(dirname ${BASH_SOURCE[0]})"/patch_hdainject.sh "$HDA"
        install_kext AppleHDA_$HDA.kext
    fi
}

function install_hda
{
    if [[ $MINOR_VER -le 9 ]]; then
        install_hdainject
    else
        install_hdazml
    fi
}

function rebuild_kernel_cache
{
    # force cache rebuild with output
    $SUDO touch $SLE && $SUDO kextcache -u /
}

function update_efi_kexts
{
    # install/update kexts on EFI/Clover/kexts/Other
    EFI=$("$(dirname ${BASH_SOURCE[0]})"/mount_efi.sh)
    echo Updating kexts at EFI/Clover/kexts/Other
    for kext in $ESSENTIAL; do
        if [[ -e $KEXTDEST/$kext ]]; then
            echo updating $EFI/EFI/CLOVER/kexts/Other/$kext
            cp -Rfp $KEXTDEST/$kext $EFI/EFI/CLOVER/kexts/Other
        fi
    done
    # remove deprecated kexts from EFI that were typically ESSENTIAL
    for kext in IntelGraphicsFixup.kext CoreDisplayFixup.kext FakePCIID_Intel_HD_Graphics.kext FakePCIID_Broadcom_WiFi.kext; do
        if [[ ! -e $KEXTDEST/$kext ]]; then
            echo removing $EFI/EFI/CLOVER/kexts/Other/$kext
            rm -Rf $EFI/EFI/CLOVER/kexts/Other/$kext
        fi
    done
    # remove FakePCIID.kext from EFI if it is the only FakePCIID kext remaining
    if [[ "$(echo $EFI/EFI/CLOVER/kexts/Other/FakePCIID*)" == "$EFI/EFI/CLOVER/kexts/Other/FakePCIID.kext" ]]; then
        echo removing $EFI/EFI/CLOVER/kexts/Other/FakePCIID.kext
        rm -Rf $EFI/EFI/CLOVER/kexts/Other/FakePCIID.kext
    fi
}

function remove_voodoops2daemon
{
    # remove VoodooPS2Daemon (deprecated)
    $SUDO rm -f /usr/bin/VoodooPS2Daemon
    $SUDO rm -f /Library/LaunchDaemons/org.rehabman.voodoo.driver.Daemon.plist
}

#EOF
