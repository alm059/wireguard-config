# !/bin/sh

# Sudo checks
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

# Defaults
server_default_address=10.0.0.1
server_default_port=51820
# end defaults

help=false
visualize=false
syntax=false # While false it hasn't found any command on the execution thread

check_run(){ # Run configuration commands
    if [ $# -gt 1 ]; then
        echo "[wg-conf]" $2
    else
        echo "[wg-conf]" $1
    fi
    if [ "$visualize" == "false" ]; then eval $1; fi
}
reminder(){
    echo "Use wg-quick up/down {<interface name>} to enable or disable an interface without deleting it"
    echo "Use wg show [<interface name>] to view the status of current interfaces"
    echo "Check wireguard service status: systemctl status wg-quick@{<interface-name>}"
}
show(){
    if [ $# -gt 0 ]; then
        check_run "cat /etc/wireguard/${1}.conf"
    else
        check_run "ls /etc/wireguard/"
    fi
}
new(){
    # Mandatory args
    if [ ! $# -ge 1 ] || [[ "$1" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    shift
    # Optional args
    address=${server_default_address}
    port=${server_default_port}
    forwarding_interface=false
    while [ $# -gt 0 ] ; do
        case "$1" in
            -a) shift; address=$1;;
            -p) shift; port=$1;;
            -f) shift; forwarding_interface=$1;;
        esac
        shift
    done

    # Commands
    private_key=`wg genkey`
    public_key=`echo "$private_key" | wg pubkey`
    echo "Server public Key: $public_key"

    check_run "ufw allow $port/udp && sudo ufw enable"

    check_run "printf \"[Interface]\nAddress = ${address}\nListenPort = ${port}\nPrivateKey = ${private_key}\n\" > /etc/wireguard/${interface_name}.conf" "printf \"[Interface]\"... > /etc/wireguard/${interface_name}.conf"
    unset -v private_key

    if [ "$forwarding_interface" != "false" ]; then
        check_run "sysctl -w net.ipv4.ip_forward=1"
        check_run "printf \"PostUp = iptables -A FORWARD -i %%i -j ACCEPT; iptables -A FORWARD -o %%i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${forwarding_interface} -j MASQUERADE\nPostDown = iptables -D FORWARD -i %%i -j ACCEPT; iptables -D FORWARD -o %%i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${forwarding_interface} -j MASQUERADE\n\" >> /etc/wireguard/${interface_name}.conf" "printf \"PostUp\"... >> /etc/wireguard/${interface_name}.conf"
        echo "Might need to modify ufw settings to allow forwarding. Edit 'ufw sysctl' to do this"
    fi

    check_run "wg-quick up ${interface_name}"
    echo "To autostart this interface execute: sudo systemctl enable wg-quick@${interface_name}.service"
}
enable-forwarding(){
    # Mandatory args
    if [ ! $# -ge 2 ] || [[ "$1" == "-"* ]] || [[ "$2" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    forwarding_interface=$2

    if [ ! -f /etc/wireguard/${interface_name}.conf ]; then
        echo "Interface config file not found"
        return
    fi
    printf "\n" >> "/etc/wireguard/${interface_name}.conf" # Add a line at the end of the file to prevent reading problems

    file=""
    forwarded=false

    # Check if enabled
    while read line; do
        if [ "$line" != "" ]; then
            if [[ "$line" == *"[Peer]"* ]]; then # set space before new peer block
                line="\n${line}"
            fi
            if [[ "$line" != "[Interface]"* ]]; then # if interface, don't write
                file="${file}${line}\n"
            fi
            if [[ "$line" == *"PostUp"* ]] || [[ "$line" == *"PostDown"* ]]; then
                forwarded=true
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;

    if [ $forwarded == "true" ]; then
        echo "Traffic forwarding could already be enabled (PostUp/Down exists)"
        return
    fi

    file="[Interface]\nPostUp = iptables -A FORWARD -i %%i -j ACCEPT; iptables -A FORWARD -o %%i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${forwarding_interface} -j MASQUERADE\nPostDown = iptables -D FORWARD -i %%i -j ACCEPT; iptables -D FORWARD -o %%i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${forwarding_interface} -j MASQUERADE\n"${file}
    echo "Adding PostUp and Post down rules to ${interface_name}.conf"
    check_run "wg-quick down ${interface_name}"
    check_run "printf \"$file\" > /etc/wireguard/${interface_name}.conf" "printf file > /etc/wireguard/${interface_name}.conf"
    echo "Allowing traffic forwarding at system level"
    check_run "sysctl -w net.ipv4.ip_forward=1"
    check_run "wg-quick up ${interface_name}"
    echo "Might need to modify ufw settings to allow forwarding. Edit 'ufw sysctl' to do this"
}
disable-forwarding(){
    # Mandatory args
    if [ ! $# -ge 1 ] || [[ "$1" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1

    if [ ! -f /etc/wireguard/${interface_name}.conf ]; then
        echo "Interface config file not found"
        return
    fi
    printf "\n" >> "/etc/wireguard/${interface_name}.conf" # Add a line at the end of the file to prevent reading problems

    file=""
    forwarded=false

    while read line; do
        if [ "$line" != "" ]; then
            if [[ "$line" == *"[Peer]"* ]]; then # set space before new peer block
                line="\n${line}"
            fi
            if [[ "$line" == *"PostUp"* ]] || [[ "$line" == *"PostDown"* ]]; then
                forwarded=true
            else
                file="${file}${line}\n"
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;


    if [ $forwarded == "true" ]; then
        check_run "wg-quick down ${interface_name}"
        check_run "printf \"$file\" > /etc/wireguard/${interface_name}.conf" "printf file > /etc/wireguard/${interface_name}.conf"
        check_run "wg-quick up ${interface_name}"
        echo "Removed PostUp and Post down rules from ${interface_name}.conf"
    else
        echo "Could not find redirection rules in the config file"
    fi
    echo "If you wish to disable traffic forwarding at system level (for all interfaces) execute: sudo sysctl -w net.ipv4.ip_forward=0"
    echo "Might need to modify ufw settings to remove forwarding too. Edit 'ufw sysctl' to do this"
}
remove(){
    # Mandatory args
    if [ ! $# -ge 1 ] || [[ "$1" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    if [ ! -f /etc/wireguard/${interface_name}.conf ]; then
        echo "Interface config file not found"
        return
    fi
    printf "\n" >> "/etc/wireguard/${interface_name}.conf" # Add a line at the end of the file to prevent reading problems

    read -p "Retype the interface name to confirm: " confirmation
    if [ "$confirmation" != "$interface_name" ]; then echo "Aborted." && return; fi


    check_run "wg-quick down ${interface_name}"
    check_run "systemctl stop wg-quick@${interface_name}.service"
    check_run "systemctl disable wg-quick@${interface_name}.service"
    check_run "rm /etc/wireguard/${interface_name}.conf"
    check_run "systemctl daemon-reload"
    check_run "systemctl reset-failed"
    echo "To completely remove the VPN configuration please close the port by removing the UFW rule: 'ufw status' && 'ufw delete RULE'"
}
peer-new(){
    # Mandatory args
    if [ ! $# -ge 5 ] || [[ "$1" == "-"* ]] || [[ "$2" != "-"* ]] || [[ "$3" == "-"* ]] || [[ "$4" != "-"* ]] || [[ "$5" == "-"* ]]; then
        help=true
        return
    fi
    interface_name=$1
    shift
    # Labelled args
    public_key=false
    ip=false
    name=""
    while [ $# -gt 0 ] ; do
        case "$1" in
            -f) shift;
                if [ -f $1 ]; then
                    public_key=$(<$1)
                else
                    echo "Public key file does not exist"; return
                fi
            ;;
            -k) shift; public_key=$1;;
            -i) shift; ip=$1;;
            -n) shift; name="# $1 \n";;
        esac
        shift
    done

    if [ ! -f /etc/wireguard/${interface_name}.conf ]; then
        echo "Interface config file not found"
        return
    fi

    if [ "$public_key" == "false" ] || [ "$ip" = "false" ]; then
        help=true
        return
    fi

    if [[ "${ip}" != *"/"* ]]; then
        echo "Remember to suffix the IP such as 10.0.0.2/32 (32 highly recommended for clients)"
        return
    fi

    printf "\n" >> "/etc/wireguard/${interface_name}.conf" # Add a line at the end of the file to prevent reading problems

    # Commands
    peer="[Peer]\n${name}PublicKey = ${public_key}\nAllowedIPs = ${ip}\n"
    file=""

    while read line; do
        if [ "$line" != "" ]; then
            if [[ "$line" == *"[Peer]"* ]]; then # set extra space before new peer block
                line="\n${line}"
            fi
            file="${file}${line//%/%%}\n"
            if [[ "$line" == *"PublicKey = ${public_key}"* ]]; then
                echo "Aborted. Public key matches with that of another peer."
                return
            fi
            if [[ "$line" == "AllowedIPs"* ]]; then
                if [[ "$line" == *"${ip}"* ]]; then
                    echo "Aborted. IP is not unique to this peer."
                    return
                fi
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;

    check_run "wg-quick down ${interface_name}"
    check_run "printf \"${file}\n${peer}\" > /etc/wireguard/${interface_name}.conf" "printf peer > /etc/wireguard/${interface_name}.conf";
    check_run "wg-quick up ${interface_name}"
    echo "Peer added to ${interface_name}.conf"
}
peer-enable(){
    # Mandatory args
    if [ ! $# -ge 3 ] || [[ "$1" == "-"* ]] || [[ "$2" != "-"* ]] || [[ "$3" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    shift
    ip=""
    name=""
    while [ $# -gt 0 ] ; do
        case "$1" in
            -n) shift; name=$1;;
            -i) shift; ip=$1;;
        esac
        shift
    done
    if [ "$ip" == "" ] && [ "$name" == "" ]; then
        help=true
        return
    fi
    if [ ! -f /etc/wireguard/${interface_name}.conf ]; then
        echo "Interface config file not found"
        return
    fi
    printf "\n" >> "/etc/wireguard/${interface_name}.conf" # Add a line at the end of the file to prevent reading problems

    file=""
    peer_temp=""
    peer_temp_enabled="" # copy of peer temp but enabled
    peer_temp_enable=false
    peer_enabled=false
    peer_count=0

    while read line; do
        if [ "$line" != "" ]; then
            # Start of a commented peer line or analizing a commented peer line
            if [[ "$line" == "# [Peer]"* ]] || [ "$peer_temp" != "" ]; then
                # Reset previous peer (add to file) and initiate new
                if [[ "$line" == *"[Peer]"* ]]; then
                    if [ "$peer_temp_enable" == "true" ]; then
                        file="${file}${peer_temp_enabled}\n"
                    else
                        file="${file}${peer_temp}\n"
                    fi
                    peer_temp=""
                    peer_temp_enabled=""
                    peer_temp_enable=false
                    peer_count=$peer_count+1
                    # If new peer is not disabled, ignore peer analysis
                    if [[ "$line" != "#"* ]]; then
                        file="${file}${line}\n"
                        continue
                    fi
                fi

                # Check if line of peer meets criteria
                if [[ "$line" == "# AllowedIPs"* ]] && [[ "$line" == *"${ip}"* ]] || [ "$line" == "# ${name}" ]; then
                    peer_temp_enable=true
                    # check if a different peer has been flagged for enabling
                    if [ $peer_enabled != "false" ] && [ "$peer_count" != "$peer_enabled" ]; then
                        echo "Aborted. Multiple peers meet the same criteria"
                        return
                    fi
                    peer_enabled=$peer_count
                fi

                # Add line to temp peer line
                peer_temp="${peer_temp}${line}\n"
                peer_temp_enabled="${peer_temp_enabled}${line:2}\n"
            else # Line not belonging to disabled peer
                if [[ "$line" == "[Peer]"* ]]; then # set extra space before new peer block
                    line="\n${line}"
                fi
                file="${file}${line//%/%%}\n"
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;
    if [ "$peer_temp_enable" == "true" ]; then
        file="${file}${peer_temp_enabled}"
    else
        file="${file}${peer_temp}"
    fi

    if [ "$peer_enabled" != "false" ]; then
        check_run "wg-quick down ${interface_name}"
        check_run "printf \"$file\" > /etc/wireguard/${interface_name}.conf" "printf file > /etc/wireguard/${interface_name}.conf"
        check_run "wg-quick up ${interface_name}"
        echo "Enabled peer ${name} ${ip} from ${interface_name}.conf"
    else
        echo "Disabled peer not found"
    fi
}
peer-disable(){
    # Mandatory args
    if [ ! $# -ge 3 ] || [[ "$1" == "-"* ]] || [[ "$2" != "-"* ]] || [[ "$3" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    shift
    ip=""
    name=""
    while [ $# -gt 0 ] ; do
        case "$1" in
            -n) shift; name=$1;;
            -i) shift; ip=$1;;
        esac
        shift
    done
    if [ "$ip" == "" ] && [ "$name" == "" ]; then
        help=true
        return
    fi
    if [ ! -f /etc/wireguard/${interface_name}.conf ]; then
        echo "Interface config file not found"
        return
    fi
    printf "\n" >> "/etc/wireguard/${interface_name}.conf" # Add a line at the end of the file to prevent reading problems

    file=""
    peer_temp=""
    peer_temp_disabled=""
    peer_temp_disable=false
    peer_disabled=false
    peer_count=0

    while read line; do
        if [ "$line" != "" ]; then
            if [ "$peer_temp" == "" ] && [[ "$line" != "[Peer]"* ]]; then #pre-peer line
                file="${file}${line//%/%%}\n"
            else # peer line
                if [[ "$line" == *"[Peer]"* ]]; then # new peer
                    # Reset
                    if [ "$peer_temp_disable" == "true" ]; then
                        file="${file}${peer_temp_disabled}\n"
                    else
                        file="${file}${peer_temp}\n"
                    fi
                    peer_temp_disable=false
                    peer_temp=""
                    peer_temp_disabled=""
                    peer_count=$peer_count+1
                # \/ check if peer meets disabled criteria. cannot find those disabled
                elif [[ "$line" == "AllowedIPs"* ]] && [[ "$line" == *"${ip}"* ]] || [ "$line" == "# ${name}" ]; then
                    peer_temp_disable=true
                    # \/ check if a different peer has been flagged for disabled
                    if [ $peer_disabled != "false" ] && [ "$peer_count" != "$peer_disabled" ]; then
                        echo "Aborted. Multiple peers meet the same criteria"
                        return
                    else
                        peer_disabled=$peer_count
                    fi
                fi

                peer_temp="${peer_temp}${line}\n"
                peer_temp_disabled="${peer_temp_disabled}# ${line}\n"
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;
    if [ "$peer_temp_disable" == "true" ]; then
        file="${file}${peer_temp_disabled}"
    else
        file="${file}${peer_temp}"
    fi

    if [ "$peer_disabled" != "false" ]; then
        check_run "wg-quick down ${interface_name}"
        check_run "printf \"$file\" > /etc/wireguard/${interface_name}.conf" "printf file > /etc/wireguard/${interface_name}.conf"
        check_run "wg-quick up ${interface_name}"
        echo "Disabled peer ${name} ${ip} from ${interface_name}.conf"
    else
        echo "Peer not found"
    fi
}
peer-remove(){
    # Mandatory args
    if [ ! $# -ge 3 ] || [[ "$1" == "-"* ]] || [[ "$2" != "-"* ]] || [[ "$3" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    printf "\n\n" >> "/etc/wireguard/${interface_name}.conf" # Add a line at the end of the file to prevent reading problems
    shift
    ip=""
    name=""
    while [ $# -gt 0 ] ; do
        case "$1" in
            -n) shift; name=$1;;
            -i) shift; ip=$1;;
        esac
        shift
    done
    if [ "$ip" == "" ] && [ "$name" == "" ]; then
        help=true
        return
    fi
    if [ ! -f /etc/wireguard/${interface_name}.conf ]; then
        echo "Interface config file not found"
        return
    fi

    file=""
    peer_temp=""
    peer_temp_delete=false
    peer_deleted=false
    peer_count=0

    while read line; do
        if [ "$line" != "" ]; then
            if [ "$peer_temp" == "" ] && [[ "$line" != *"[Peer]"* ]]; then #pre-peer line
                file="${file}${line//%/%%}\n"
            else # peer line
                if [[ "$line" == *"[Peer]"* ]]; then # new peer
                    # Reset
                    if [ "$peer_temp_delete" == "false" ]; then
                        file="${file}${peer_temp}\n"
                    fi
                    peer_temp_delete=false
                    peer_temp=""
                    peer_count=$peer_count+1
                # \/ check if peer meets deletion criteria. can find those disabled
                elif ([[ "$line" == *"AllowedIPs"* ]] && [[ "$line" == *"${ip}"* ]] && [[ "${ip}" != "" ]]) || ([[ "$line" == *"# ${name}"* ]] && [ "${name}" != "" ] ); then
                    peer_temp_delete=true
                    # \/ check if a different peer has been flagged for deletion
                    echo ${line}
                    if [ $peer_deleted != "false" ] && [ "$peer_count" != "$peer_deleted" ]; then
                        echo "Aborted. Multiple peers meet the same criteria"
                        return
                    else
                        peer_deleted=$peer_count
                    fi
                fi

                if [ "$peer_temp_delete" == "false" ]; then # The peer is safe
                    peer_temp="${peer_temp}${line}\n"
                fi
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;
    if [ "$peer_temp_delete" == "false" ]; then
        file="${file}${peer_temp}"
    fi

    if [ "$peer_deleted" != "false" ]; then
        check_run "wg-quick down ${interface_name}"
        check_run "printf \"$file\" > /etc/wireguard/${interface_name}.conf" "printf file > /etc/wireguard/${interface_name}.conf"
        check_run "wg-quick up ${interface_name}"
        echo "Removed peer ${name} ${ip} from ${interface_name}.conf"
    else
        echo "Peer not found"
    fi
}


while [ $# -gt 0 ] && [ "$syntax" == "false" ] ; do
    case "$1" in
        # OPTIONS
        -h|--help) help=true ;;
        -v|--visualize) visualize=true; echo "~Visualize mode~" ;;
        # COMMANDS
        reminder)
            syntax="reminder"
            if [ $help != "true" ]; then shift; reminder $*; fi
        ;;
        show)
            syntax="show [<interface-name>]"
            if [ $help != "true" ]; then shift; show $*; fi
        ;;
        new)
            syntax="new {<interface-name>} [-a <address>] [-p <port>] [-f <forwarding-interface>]"
            if [ "$help" != "true" ] ; then shift; new $*; fi # if help needed, don't execute
        ;;
        enable-forwarding)
            syntax="enable-forwarding {<interface-name>} {<forwarding-interface>}"
            if [ $help != "true" ]; then shift; enable-forwarding $*; fi
        ;;
        disable-forwarding)
            syntax="disable-forwarding {<interface-name>}"
            if [ $help != "true" ]; then shift; disable-forwarding $*; fi
        ;;
        remove)
            syntax="remove {<interface-name>}"
            if [ $help != "true" ]; then shift; remove $*; fi
        ;;
        peer-new)
            syntax="peer-new {<interface-name>} {-f <public key file> | -k <public key>} {-i <peer-ip>} [-n <name or identifier (without spaces)>]"
            if [ $help != "true" ]; then shift; peer-new $*; fi
        ;;
        peer-enable)
            syntax="peer-enable {<interface-name>} {-i <peer-ip> | -n <name or identifier (without spaces)>}"
            if [ $help != "true" ]; then shift; peer-enable $*; fi
        ;;
        peer-disable)
            syntax="peer-disable {<interface-name>} {-i <peer-ip> | -n <name or identifier (without spaces)>}"
            if [ $help != "true" ]; then shift; peer-disable $*; fi
        ;;
        peer-remove)
            syntax="peer-remove {<interface-name>} {-i <peer-ip> | -n <name or identifier (without spaces)>}"
            if [ $help != "true" ]; then shift; peer-remove $*; fi
        ;;
        *)
            if [ ! -z $1 ] ; then # Avoid flagging stopping on empty arguments
                help=true
                syntax="Unknown command: '$1'"
            fi
        ;;
    esac
    shift
done

if [ "$help" == "true" ] && [ "$syntax" == "false" ] ; then # Full help
    echo "Syntax: bash wg-config.sh [options] <command> <arguments> [optional arguments]";
    echo "Available commands: new, remove, enable-forwarding, disable-forwarding, peer-new, peer-remove, peer-enable, peer-disable, reminder, show"
elif [ "$help" == "true" ] && [ "$syntax" != "false" ] ; then # Command explanation or wrong args
    echo $syntax
elif [ "$help" == "false" ] && [ "$syntax" == "false" ] ; then # Running without command or help
    echo "Syntax: bash wireguard_server.sh [options] <command> <arguments> [optional arguments]";

fi
