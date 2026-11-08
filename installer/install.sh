#!/bin/bash
args=("$@")

if [[ ${#args[@]} -gt 0 ]]
then
    cd ${args[0]}
else
    cd ~
fi
ROOT_PATH="$(pwd)/rf24libs"
REPOS=("RF24" "RF24Network" "RF24Mesh" "RF24Gateway")
DO_INSTALL=("0" "0" "0" "0")
CHOOSE_VERSION="N"
EXAMPLE_PATH=("examples_linux" "examples_RPi" "examples_RPi" "examples")
SUGGESTED_EXAMPLE=("gettingstarted" "helloworld_tx" "RF24Mesh_Example_Master" "RF24Gateway_ncurses")
CMAKE_OPTIONS=("" "" "" "")
USE_CCM="N"

# TODO Remove this when ready for master branches (or improve it via CLI args)
BRANCHES=("master" "master" "master" "master")

echo $'\n'"RF24 libraries installer by TMRh20 and 2bndy5"
echo "report issues at https://github.com/nRF24/RF24/issues"
echo $'\n'"******************** NOTICE **********************"
echo "This installer will create a 'rf24libs' folder for installation of selected libraries"
echo "To prevent mistaken deletion, users must manually delete existing library folders within 'rf24libs' if upgrading"
echo "Run 'sudo rm -r $ROOT_PATH' to clear the entire directory"
if [[ ! -d $ROOT_PATH ]]
then
    echo $'\n'"Creating $ROOT_PATH folder."
    mkdir $ROOT_PATH
fi

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

read -p "Choose versions to install (Default: Install latest code from master) [y/N]? " CHOOSE_VERSION

for index in "${!REPOS[@]}"
do
    read -p "Do you want to install the ${REPOS[index]} library, [y/N]? " answer
    case ${answer^^} in
        Y ) DO_INSTALL[index]=1
            if [ "${CHOOSE_VERSION^^}" = "Y" ]
            then
                read -p "Which version/branch of ${REPOS[index]} to install (default is ${BRANCHES[index]})? " version
                if [[ ${#version} -gt 0 ]]; then
                    BRANCHES[index]=$version
                fi
            fi
            ;;
        * ) ;;
    esac
done

if [[ ${DO_INSTALL[1]} > 0 || ${DO_INSTALL[2]} > 0 || ${DO_INSTALL[3]} > 0 ]]
then
    echo $'\n'"AES-CCM encryption lets Linux nodes communicate with nRF52840 nodes using nrf_to_nrf encryption."
    echo "RF24Network, RF24Mesh and RF24Gateway must all be built with it for RF24Gateway to use it."
    read -p "Build with CCM encryption support (RF24NETWORK_CCM) [y/N]? " USE_CCM
    case ${USE_CCM^^} in
        Y ) CMAKE_OPTIONS[1]="-DRF24NETWORK_CCM=ON"
            CMAKE_OPTIONS[2]="-DRF24NETWORK_CCM=ON"
            CMAKE_OPTIONS[3]="-DRF24NETWORK_CCM=ON"
            # Replacing only the header would leave the installed RF24Network lib built from a different
            # RF24CCM.h than everything compiled after it, so reinstall RF24Network instead
            if [[ ${DO_INSTALL[1]} = 0 ]]
            then
                if [[ ! -f "/usr/local/include/RF24Network/RF24CCM.h" ]]
                then
                    echo "The installed RF24Network has no CCM support. Adding RF24Network to the installation."
                    DO_INSTALL[1]=1
                elif [[ -f "$ROOT_PATH/RF24Network/RF24CCM.h" ]] && ! cmp -s "$ROOT_PATH/RF24Network/RF24CCM.h" "/usr/local/include/RF24Network/RF24CCM.h"
                then
                    echo "The installed RF24CCM.h differs from $ROOT_PATH/RF24Network/RF24CCM.h. Adding RF24Network to the installation."
                    DO_INSTALL[1]=1
                fi
            fi
            # A CCM RF24Gateway calls the ESBMesh<..., RF24CCM> functions, so programs linking it fail
            # unless the installed RF24Mesh was built with CCM too
            if [[ ${DO_INSTALL[3]} = 1 && ${DO_INSTALL[2]} = 0 ]] && ! nm -DC /usr/local/lib/librf24mesh.so 2> /dev/null | grep -q RF24CCM
            then
                echo "The installed RF24Mesh has no CCM support. Adding RF24Mesh to the installation."
                DO_INSTALL[2]=1
            fi
            ;;
        * ) ;;
    esac
fi

if [[ ${DO_INSTALL[0]} > 0 ]]
then
    echo "WARNING: It is advised to remove the previously installed RF24 library first."
    echo $'\t'"This is done to avoid Runtime conflicts."
    if [[ -f "/usr/local/lib/librf24.so" ]]
    then
        echo "Uninstalling previously installed RF24 lib (/usr/local/lib/librf24.so)"
        sudo rm /usr/local/lib/librf24.*
        # check for presence of a very old install
        if [[ -f "/usr/local/lib/librf24-bcm.so" ]]
        then
            sudo rm /usr/local/lib/librf24-bcm.so
        fi
        sudo rm -r /usr/local/include/RF24
    fi
fi

if [[ ${DO_INSTALL[3]} > 0  && ! -f "/usr/lib/$(ls /usr/lib/gcc | tail -1)/libcurses.so" ]]
then
    read -p "    Install ncurses library, recommended for RF24Gateway [y/N]? " answer
    case ${answer^^} in
        Y ) sudo apt-get install libncurses5-dev;;
        * ) SUGGESTED_EXAMPLE[3]=RF24GatewayNode;;
    esac
    echo ""
fi

echo "*** Which hardware driver library do you wish to use? ***"
echo "1. SPIDEV (most compatible, Default)"
echo "2. WiringPi"
echo "3. MRAA (Intel Devices)"
echo "4. PiGPIO"
echo "5. BCM2835 Driver (for RPi only)"
echo "6. LittleWire"
read answer
case ${answer^^} in
    1) RF24DRIVER+="SPIDEV";;
    2) RF24DRIVER+="wiringPi";;
    3) RF24DRIVER+="MRAA";;
    4) RF24DRIVER+="pigpio";;
    5) RF24DRIVER+="RPi";;
    6) RF24DRIVER+="LittleWire";;
    *) RF24DRIVER+="SPIDEV";;
esac

# set an env var for easier reuse (specific to RF24 repos).
# Any applicable CMakeLists.txt is configured to use this when it is set.
export RF24_DRIVER=$RF24DRIVER

# ensure we have a fresh build directory
create_build_env() {
    if [[ -f "Makefile.inc" ]]; then
        rm Makefile.inc
    fi
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
    if [[ ! -d "$ROOT_PATH/${REPOS[$1]}" ]]
    then
        git clone https://github.com/nRF24/${REPOS[$1]} $ROOT_PATH/${REPOS[$1]}
    else
        echo "Using already cloned repo $ROOT_PATH/${REPOS[$1]}"
    fi
    echo ""
    cd $ROOT_PATH/${REPOS[$1]}
    git fetch --all
    git checkout ${BRANCHES[$1]}
    if [[ -f "CMakeLists.txt" ]]; then
        create_build_env
        cmake .. ${CMAKE_OPTIONS[$1]}
    elif [[ -f "configure" ]]; then
        ./configure --driver=$RF24_DRIVER
    fi
    if ! make
    then
        echo "Building lib ${REPOS[$1]} failed. Quiting now."
        exit 1
    fi
    if ! sudo make install
    then
        echo "Installing lib ${REPOS[$1]} failed. Quiting now."
        exit 1
    fi
    # RF24Mesh, RF24Gateway and gateway programs compile against the installed RF24CCM.h,
    # so it must be the same file the RF24Network lib was just built from
    if [[ ${USE_CCM^^} = "Y" && ${REPOS[$1]} = "RF24Network" ]]
    then
        SRC_CCM="$ROOT_PATH/RF24Network/RF24CCM.h"
        DST_CCM="/usr/local/include/RF24Network/RF24CCM.h"
        if ! cmp -s "$SRC_CCM" "$DST_CCM"
        then
            echo "Installed $DST_CCM does not match $SRC_CCM. Replacing it."
            sudo rm -f "$DST_CCM"
            if ! sudo install -D -m 644 "$SRC_CCM" "$DST_CCM" || ! cmp -s "$SRC_CCM" "$DST_CCM"
            then
                echo "Replacing $DST_CCM failed. Quiting now."
                exit 1
            fi
        fi
        echo "Verified the installed RF24CCM.h matches $SRC_CCM"
    fi
    CWD=$(pwd)
    if [[ "$CWD" != "*/build" ]]; then
        sudo ldconfig
    fi
    read -p $'\n'"Do you want to build the ${REPOS[$1]} examples [Y/n]? " answer
    case ${answer^^} in
        N ) ;;
        * )
            cd $ROOT_PATH/${REPOS[$1]}/${EXAMPLE_PATH[$1]}
            if [[ -f "CMakeLists.txt" ]]; then
                create_build_env
                cmake ..
            fi
            if ! make
            then
                echo "Building examples for lib ${REPOS[$1]} failed. Quiting now."
                exit 1
            fi
            echo ""
            echo "Complete! To run the example:"
            CWD=$(pwd)
            echo "cd $CWD"
            echo "sudo ./${SUGGESTED_EXAMPLE[$1]}"
    esac
}

# Install RF24Gateway as a systemd service (rf24gatewayd), either headless or with the ncurses
# interface in a screen session. It runs at boot as a non-root user with only CAP_NET_ADMIN,
# which needs the SPIDEV driver
install_gateway_service() {
    SERVICE_PATH="$ROOT_PATH/RF24Gateway/service"
    echo ""
    read -p "Do you want to install RF24Gateway as a service that starts at boot (runs as a non-root user) [y/N]? " answer
    case ${answer^^} in
        Y ) ;;
        * ) return;;
    esac
    echo "*** How should the RF24Gateway service run? ***"
    echo "1. Headless (no interface, output goes to the system log)"
    echo "2. GUI-noInterrupts (ncurses interface, polls the radio, Default)"
    echo "3. GUI-Interrupts (ncurses interface, uses the radio's IRQ pin)"
    read answer
    case $answer in
        1) SERVICE_MODE="headless";;
        3) SERVICE_MODE="ncursesint";;
        *) SERVICE_MODE="ncurses";;
    esac
    if [[ ! -f "$SERVICE_PATH/CMakeLists.txt" ]]
    then
        echo "This RF24Gateway branch has no service/ folder ($SERVICE_PATH). Skipping the service."
        return
    fi
    if [[ "$RF24_DRIVER" != "SPIDEV" ]]
    then
        echo "The service needs the SPIDEV driver to run without root, but $RF24_DRIVER was chosen. Skipping the service."
        return
    fi
    if ! command -v systemctl &> /dev/null
    then
        echo "systemd was not found. Skipping the service."
        return
    fi
    if [[ "$SERVICE_MODE" != "headless" ]]
    then
        if [[ ! -f "/usr/lib/$(ls /usr/lib/gcc | tail -1)/libcurses.so" ]]
        then
            echo "Installing ncurses (the service shows the ncurses gateway interface)"
            sudo apt-get install -y libncurses-dev
        fi
        if ! command -v screen &> /dev/null
        then
            echo "Installing screen (the service runs the gateway interface in a screen session)"
            sudo apt-get install -y screen
        fi
    fi
    SERVICE_CCM="OFF"
    ENCRYPT_SERVICE="N"
    if [[ ${USE_CCM^^} = "Y" ]]
    then
        SERVICE_CCM="ON"
        echo ""
        echo "AES-CCM encryption: every node must use the same key. Nodes without encryption"
        echo "(e.g. Arduino + nRF24L01) can't communicate with an encrypting gateway."
        read -p "Enable AES-CCM encryption in the RF24Gateway service [y/N]? " ENCRYPT_SERVICE
    fi

    read -p "User to run the service as (default rf24gateway, created if needed): " SERVICE_USER
    if [[ ${#SERVICE_USER} = 0 ]]; then
        SERVICE_USER="rf24gateway"
    fi
    if [[ ! "$SERVICE_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]
    then
        echo "'$SERVICE_USER' is not a valid user name. Skipping the service."
        return
    fi

    # Ask for the settings on every install. A reinstall shows the values in the existing config,
    # and pressing Enter keeps them
    CONFIG_FILE="/etc/rf24gateway/rf24gateway.conf"
    # Print the value of "key = value" in the existing config, or $2 if it isn't set
    get_service_config() {
        local value
        value=$(grep -s "^$1 = " "$CONFIG_FILE" | tail -1 | cut -d= -f2- | sed 's/#.*//; s/^ *//; s/ *$//')
        echo "${value:-$2}"
    }
    CURRENT_IP=$(get_service_config ip 10.10.2.2)
    CURRENT_MASK=$(get_service_config netmask 255.255.255.0)
    CURRENT_CHANNEL=$(get_service_config channel 97)
    CURRENT_ALLOWED=$(get_service_config allowed_nodes "")
    echo ""
    echo "Gateway settings (press Enter to keep the value shown):"
    read -p "IP address of the tun_nrf24 interface ($CURRENT_IP): " SERVICE_IP
    SERVICE_IP=${SERVICE_IP:-$CURRENT_IP}
    read -p "Netmask ($CURRENT_MASK): " SERVICE_MASK
    SERVICE_MASK=${SERVICE_MASK:-$CURRENT_MASK}
    read -p "Radio channel, 0 to 125 ($CURRENT_CHANNEL): " SERVICE_CHANNEL
    SERVICE_CHANNEL=${SERVICE_CHANNEL:-$CURRENT_CHANNEL}
    if [[ ! "$SERVICE_CHANNEL" =~ ^[0-9]+$ ]] || (( 10#$SERVICE_CHANNEL > 125 ))
    then
        echo "'$SERVICE_CHANNEL' is not a channel from 0 to 125. Keeping $CURRENT_CHANNEL."
        SERVICE_CHANNEL=$CURRENT_CHANNEL
    fi
    echo "NodeIDs allowed on the mesh, separated by commas or spaces. 'none' lets any node join."
    read -p "Allowed nodeIDs (${CURRENT_ALLOWED:-none}): " SERVICE_ALLOWED
    SERVICE_ALLOWED=${SERVICE_ALLOWED:-${CURRENT_ALLOWED:-none}}
    if [[ ${SERVICE_ALLOWED,,} != "none" ]]
    then
        # Same rules as rf24gatewayd: decimal nodeIDs from 1 to 255. Store them as "2, 3, 4"
        ids=$(echo "$SERVICE_ALLOWED" | tr ',\t' '  ' | tr -s ' ' | sed 's/^ //; s/ $//')
        for id in $ids
        do
            if [[ ! "$id" =~ ^[0-9]+$ ]] || (( 10#$id < 1 || 10#$id > 255 ))
            then
                echo "'$id' is not a nodeID from 1 to 255. Keeping ${CURRENT_ALLOWED:-none}."
                ids=""
                break
            fi
        done
        if [[ ${#ids} -gt 0 ]]; then
            SERVICE_ALLOWED=${ids// /, }
        else
            SERVICE_ALLOWED=${CURRENT_ALLOWED:-none}
        fi
    fi
    SERVICE_IRQ=""
    if [[ "$SERVICE_MODE" = "ncursesint" ]]
    then
        CURRENT_IRQ=$(grep -s "^irq_pin = " "$CONFIG_FILE" | cut -d= -f2 | tr -d ' ')
        read -p "GPIO pin connected to the radio's IRQ pin (default ${CURRENT_IRQ:-24}): " SERVICE_IRQ
        if [[ ${#SERVICE_IRQ} -gt 0 && ! "$SERVICE_IRQ" =~ ^[0-9]+$ ]]
        then
            echo "'$SERVICE_IRQ' is not a GPIO number. Keeping ${CURRENT_IRQ:-24}."
            SERVICE_IRQ=""
        fi
    fi

    cd "$SERVICE_PATH"
    create_build_env
    # Choose the key before building, so a cancelled or invalid key entry changes nothing
    KEY_FILE="/etc/rf24gateway/rf24gateway.key"
    NEW_KEY=""
    if [[ ${ENCRYPT_SERVICE^^} = "Y" ]]
    then
        # Print a 32 hex digit key as a C array: {0x01, 0x02, ...}
        key_as_array() {
            echo "{$(echo "$1" | sed 's/../0x&, /g; s/, $//')}"
        }
        # Read a key in any accepted format into NEW_KEY. Returns 1 if it isn't 16 bytes.
        # Same rules as rf24gatewayd: use the part between braces if present, drop 0x prefixes
        parse_key() {
            local text="$1"
            if [[ "$text" == *"{"* ]]; then
                text=${text#*\{}
                text=${text%%\}*}
            fi
            NEW_KEY=$(echo "$text" | sed 's/0[xX]//g' | tr -cd '0-9a-fA-F' | tr 'A-F' 'a-f')
            [[ ${#NEW_KEY} = 32 ]]
        }
        show_key_formats() {
            echo ""
            echo "Accepted key formats (16 bytes, in the same order as nrf_to_nrf radio.setKey()):"
            echo "  1. The key line from your sketch:  uint8_t key[16] = {0x01, 0x02, ..., 0x10};"
            echo "  2. A C array:                      {0x01, 0x02, ..., 0x10}"
            echo "  3. 32 hex digits:                  0102030405060708090a0b0c0d0e0f10"
            echo "Only the part between { } is read. 0x prefixes, commas, spaces and colons are ignored."
            echo "Outside braces, don't include other text: letters a-f in words would be read as key digits."
            echo ""
        }

        answer="N"
        if sudo test -f "$KEY_FILE"
        then
            # Show the key, so an old one left by an earlier install isn't kept by mistake
            if parse_key "$(sudo cat "$KEY_FILE" | sed 's/#.*//')"
            then
                echo "$KEY_FILE already holds this key:"
                echo "    $(key_as_array "$NEW_KEY")"
            else
                echo "$KEY_FILE exists, but doesn't hold a valid 16 byte key."
            fi
            NEW_KEY=""
            read -p "Keep the existing encryption key [Y/n]? " answer
            answer=${answer:-Y}
        fi
        if [[ ${answer^^} != "Y" ]]
        then
            echo "1. Generate a new random key"
            echo "2. Enter the key your nrf_to_nrf nodes already use (you can also paste it right here)"
            read -p "Choose 1 or 2, or paste your key now (default 1): " key_input
            case $key_input in
                ""|1) NEW_KEY=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
                    echo "Generated a new random key."
                    ;;
                *)  if [[ "$key_input" = "2" ]]
                    then
                        echo "Paste the key line from your nrf_to_nrf sketch, e.g.:"
                        echo "    uint8_t key[16] = {0x01, 0x02, 0x03, ..., 0x10};"
                        echo "Type h and press Enter to see all accepted formats, or press Enter alone to skip the service."
                        key_input=""
                    fi
                    while true
                    do
                        if [[ ${#key_input} = 0 ]]
                        then
                            read -p "Key: " key_input
                            if [[ ${#key_input} = 0 ]]
                            then
                                echo "No key entered. Skipping the service."
                                return
                            fi
                        fi
                        if [[ ${key_input,,} = "h" ]]
                        then
                            show_key_formats
                        elif ! parse_key "$key_input"
                        then
                            echo "The key must be 16 bytes (32 hex digits), but ${#NEW_KEY} digits were found. Try again (h for help)."
                        else
                            # Show the key as it will be used, so a mistyped or mis-pasted key is caught here
                            echo "The key was read as:"
                            echo "    $(key_as_array "$NEW_KEY")"
                            read -p "Use this key [Y/n]? " answer
                            if [[ ${answer^^} != "N" ]]
                            then
                                break
                            fi
                            echo "Enter the key again, or press Enter alone to skip the service."
                        fi
                        key_input=""
                    done
                    ;;
            esac
        fi
    fi

    cmake .. -DRF24GATEWAY_USER="$SERVICE_USER" -DRF24GATEWAY_SERVICE_MODE="$SERVICE_MODE" -DRF24NETWORK_CCM="$SERVICE_CCM"
    if ! make
    then
        echo "Building the RF24Gateway service failed. Quiting now."
        exit 1
    fi
    if ! sudo make install
    then
        echo "Installing the RF24Gateway service failed. Quiting now."
        exit 1
    fi

    # Set "key = value" in the config. Otherwise a commented-out "#key = " line (as in the sample
    # config) is replaced, and the line is added if an older config doesn't have it at all
    set_service_config() {
        if grep -q "^$1 = " "$CONFIG_FILE"; then
            sudo sed -i "s|^$1 = .*|$1 = $2|" "$CONFIG_FILE"
        elif grep -q "^#$1 = " "$CONFIG_FILE"; then
            sudo sed -i "0,/^#$1 = .*/s||$1 = $2|" "$CONFIG_FILE"
        else
            echo "$1 = $2" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi
    }
    set_service_config ip "$SERVICE_IP"
    set_service_config netmask "$SERVICE_MASK"
    set_service_config channel "$SERVICE_CHANNEL"
    if [[ ${SERVICE_ALLOWED,,} = "none" ]]; then
        # Comment the setting out, so the example stays in the file
        sudo sed -i "s/^allowed_nodes = /#allowed_nodes = /" "$CONFIG_FILE"
    else
        set_service_config allowed_nodes "$SERVICE_ALLOWED"
    fi
    if [[ ${#SERVICE_IRQ} -gt 0 ]]
    then
        set_service_config irq_pin "$SERVICE_IRQ"
    fi
    if [[ ${ENCRYPT_SERVICE^^} = "Y" ]]
    then
        if [[ ${#NEW_KEY} = 32 ]]
        then
            KEY_ARRAY=$(echo "$NEW_KEY" | sed 's/../0x&, /g; s/, $//')
            # umask 027: the key is never readable by other users, even briefly
            printf '# AES-CCM key for rf24gatewayd, in the same byte order as nrf_to_nrf setKey().\n# Every node must use the same key\n{%s}\n' "$KEY_ARRAY" \
                | sudo sh -c 'umask 027; cat > "$1"' sh "$KEY_FILE"
            echo $'\n'"Use this key on your nrf_to_nrf nodes (it is saved in $KEY_FILE):"
            echo "    uint8_t key[16] = {$KEY_ARRAY};"
            echo "    radio.setKey(key);"
            echo "    radio.enableEncryption = true;"
            echo "nrf_to_nrf nodes must keep 32 byte frames: don't call radio.enableDynamicPayloads(123) on them."$'\n'
        else
            echo "Keeping the existing key. View it with: sudo cat $KEY_FILE"
        fi
        sudo chown root:"$SERVICE_USER" "$KEY_FILE"
        sudo chmod 640 "$KEY_FILE"
        set_service_config encryption 1
        set_service_config encryption_key_file "$KEY_FILE"
    elif [[ $SERVICE_CCM = "ON" ]]
    then
        set_service_config encryption 0
    elif grep -q "^encryption = 1" "$CONFIG_FILE"
    then
        echo "Warning: $CONFIG_FILE has encryption = 1, but the service was built without CCM support."
        echo "         It won't start until it's rebuilt with CCM support, or encryption is set to 0."
    fi

    # The sysusers.d file adds the user to the spi and gpio groups. Check it worked
    for group in spi gpio
    do
        if ! id -nG "$SERVICE_USER" 2> /dev/null | grep -qw $group
        then
            echo "Warning: $SERVICE_USER is not in the $group group. Add it with: sudo usermod -aG $group $SERVICE_USER"
        fi
    done

    sudo systemctl daemon-reload
    sudo systemctl enable rf24gateway
    echo "The RF24Gateway service is installed and will start at boot."
    echo "Settings: $CONFIG_FILE    Data (dhcplist.txt, routing.txt): /var/lib/rf24gateway"
    echo "To change the settings, e.g. the allowed_nodes list, edit $CONFIG_FILE, then run: sudo systemctl restart rf24gateway"

    # Another gateway using the radio would conflict, so don't start one alongside it
    if pgrep -f "RF24Gateway_|RF24GatewayNode" > /dev/null
    then
        echo "Another RF24Gateway program is running. Stop it, then run: sudo systemctl start rf24gateway"
    else
        read -p "Start the service now [Y/n]? " answer
        case ${answer^^} in
            N ) echo "Start it later with: sudo systemctl start rf24gateway";;
            * ) sudo systemctl restart rf24gateway
                sleep 2
                systemctl --no-pager --lines=5 status rf24gateway;;
        esac
    fi
    if [[ "$SERVICE_MODE" = "headless" ]]
    then
        echo "View the gateway output with: journalctl -u rf24gateway -f"
    else
        echo "View the gateway interface with: rf24gateway-ui    (detach with Ctrl-A then D)"
    fi
}

for index in "${!REPOS[@]}"
do
    if [[ ${DO_INSTALL[index]} > 0 ]]
    then
        install_repo $index
    fi
done

if [[ ${DO_INSTALL[3]} > 0 ]]
then
    install_gateway_service
fi

INSTALL_PYRF24="N"
echo $'\n'
read -p "Would you like to install the unified python wrapper package (pyrf24) [y/N]?" INSTALL_PYRF24
case ${INSTALL_PYRF24^^} in
    Y )
        if [[ ! -d "$ROOT_PATH/pyRF24" ]]
        then
            git clone https://github.com/nRF24/pyRF24 $ROOT_PATH/pyRF24
        else
            echo "Using already cloned repo $ROOT_PATH/pyRF24"
        fi
        cd $ROOT_PATH/pyRF24
        echo $'\nInitializing frozen submodules\n'
        git submodule update --init
        echo $'\nInstalling build prequisites.\n'
        python3 -m pip install -r requirements.txt
        echo $'\nInstalling pyrf24 package (from source).\n'
        # building from src respects the selected $RF24_DRIVER ('pip install pyrf24' strictly uses SPIDEV)
        python3 -m pip install .
        ;;
esac
echo $'\n\n'"*** Installer Complete ***"
echo "See http://tmrh20.github.io for documentation"
echo "See http://tmrh20.blogspot.com for info "
echo $'\n'"Listing repositories in $ROOT_PATH"
ls ${ROOT_PATH}

# clean up env var
unset RF24_DRIVER
