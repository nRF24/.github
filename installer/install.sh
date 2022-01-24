#!/bin/bash
args=("$@")

ROOT_PATH="~"
if [[ ${#args[@]} -gt 0 ]]
then
    ROOT_PATH=${args[0]}
fi

ROOT_PATH+="/rf24libs"
REPOS=("RF24" "RF24Network" "RF24Mesh" "RF24Gateway")
DO_INSTALL=("0" "0" "0" "0")
EXAMPLE_PATH=("examples_linux" "examples_RPi" "examples_RPi" "examples")
SUGGESTED_EXAMPLE=("gettingstarted" "helloworld_tx" "RF24Mesh_Example_Master" "RF24Gateway_ncurses")

# TODO Remove this when ready for master branches (or improve it via CLI args)
BRANCHES=("pigpio" "pigpio-support" "pigpio-support" "pigpio-support")

echo $'\n'"RF24 libraries installer by TMRh20 and 2bndy5"
echo "report issues at https://github.com/nRF24/RF24/issues"
echo $'\n'"******************** NOTICE **********************"
echo "This installer will create a 'rf24libs' folder for installation of selected libraries"
echo "To prevent mistaken deletion, users must manually delete existing library folders within 'rf24libs' if upgrading"
echo "Run 'sudo rm -r rf24libs' to clear the entire directory"
if [[ ! -d $ROOT_PATH ]]
then
    echo $'\n'"Creating $ROOT_PATH folder."
    mkdir $ROOT_PATH
fi

echo "WARNING: It is advised to remove the previously installed RF24 library first."
echo $'\t'"This is done to avoid Runtime conflicts."
if [[ -f "/usr/local/lib/librf24.so" ]]
then
    echo "Uninstalling previously install RF24 lib (/usr/local/lib/librf24.so)"
    sudo rm /usr/local/lib/librf24.*
    # check for presence of a very old install
    if [[ -f "/usr/local/lib/librf24-bcm.so" ]]
    then 
        sudo rm /usr/local/lib/librf24-bcm.so
    fi
    sudo rm -r /usr/local/include/RF24
fi
echo $'\n'

if ! command -v git &> /dev/null
then
    echo "Installing git from apt-get"
    sudo apt-get install git
fi
if ! command -v cmake &> /dev/null
then
    echo "Installing cmake from apt-get"
    sudo apt-get install cmake
fi

for index in "${!REPOS[@]}"
do
    answer=""
    read -p "Do you want to install the ${REPOS[index]} library, [y/N]? " answer
    case ${answer^^} in
        Y ) DO_INSTALL[index]=1;;
    esac
done

if [[ ${DO_INSTALL[3]} > 0 ]]
then
    answer=""
    read -p "    Install ncurses library, recommended for RF24Gateway [y/N]? " answer
    case ${answer^^} in
        Y ) sudo apt-get install libncurses5-dev;;
        * ) SUGGESTED_EXAMPLE[3]=RF24GatewayNode;;
    esac
    echo ""
fi

echo "*** Which hardware driver library do you wish to use? ***"
echo "1. BCM2835 Driver (aka RPi)"
echo "2. SPIDEV (Most Compatibe, Default)"
echo "3. WiringPi (support deprecated)"
echo "4. MRAA (Intel Devices)"
echo "5. PiGPIO"
echo "6. LittleWire"
answer=""
read answer
case ${answer^^} in
    1) RF24DRIVER+="RPi";;
    2) RF24DRIVER+="SPIDEV";;
    3) RF24DRIVER+="wiringPi";;
    4) RF24DRIVER+="MRAA";;
    5) RF24DRIVER+="pigpio";;
    6) RF24DRIVER+="LittleWire";;
    *) RF24DRIVER+="SPIDEV";;
esac

# answer=""
# read -p "Would like to create an installable package [Y/n]? " answer
# case ${answer^^} in
#     Y ) 
#         if ! command -v rpmbuild &> /dev/null
#         then
#             echo "Installing rpm from apt-get"
#             sudo apt-get install rpm
#         fi
#         RUN_CPACK=1;;
#     N ) RUN_CPACK=0;;
# esac

# set an env var for easier reuse (specific to RF24 repos).
# Any applicable CMakeLists.txt is configured to use this when it is set.
export RF24_DRIVER=$RF24DRIVER

# ensure we have a fresh build directory
create_build_env() {
    if [[ -d "./build" ]]
    then
        echo "Purging build environment."$'\n'
        sudo rm -r build/
    fi
    mkdir build
    cd build
}

# array index is a required arg
install_repo() {
    echo $'\n'"Installing ${REPOS[$1]} Repo..."
    echo ""
    if [[ ! -d "$ROOT_PATH/${REPOS[$1]}" ]]
    then
        git clone https://github.com/nRF24/${REPOS[$1]} $ROOT_PATH/${REPOS[$1]}
    else
        echo "Using already cloned repo $ROOT_PATH/${REPOS[$1]}"
    fi
    echo ""
    cd $ROOT_PATH/${REPOS[$1]}
    git checkout ${BRANCHES[$1]}
    create_build_env
    cmake ..
    make
    # if [[ $RUN_CPACK > 0 ]]
    # then
    #     sudo cpack
    # fi
    sudo make install
    cd ../../..
    answer=Y
    read -p $'\n'"Do you want to build the ${REPOS[$1]} examples [Y/n]? " answer
    case ${answer^^} in
        N ) ;;
        * )
            cd $ROOT_PATH/${REPOS[$1]}/${EXAMPLE_PATH[$1]}
            create_build_env
            cmake ..
            make
            cd ../../../..
            echo ""
            echo "Complete! To run the example:"
            echo "cd $ROOT_PATH/${REPOS[$1]}/${EXAMPLE_PATH[$1]}/build"
            echo "sudo ./${SUGGESTED_EXAMPLE[$1]}";;
    esac
}

for index in "${!REPOS[@]}"
do
    if [[ ${DO_INSTALL[index]} > 0 ]]
    then
        install_repo $index
    fi
done

echo $'\n\n'
echo "*** Installer Complete ***"
echo "See http://tmrh20.github.io for documentation"
echo "See http://tmrh20.blogspot.com for info "
echo ""
echo "Listing repositories in $ROOT_PATH"
ls ${ROOT_PATH}

# clean up env var
unset RF24_DRIVER
