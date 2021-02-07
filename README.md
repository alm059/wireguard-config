Definition  
    wireguard-config: manage wireguard interfaces with a single command  

Synopsis  
    wireguard.sh [options] <command> <arguments> [optional arguments]  

Description  
    Taking advantage of the simplicity of WireGuard, this script aims to simplify basic operations, with common options which should suit most use cases, for the VPN creation, configuration, management and removal of WireGuard interfaces with single commands.  
    This intends to be a basic configurator which tries to abstract the firewall and system configuration from the user, and it will always manage the VPN by editing a file in /etc/wireguard/[interface name].conf where interface name is the name set by the user. Most customizations which can be carried out in the conf file (such as editing peer data, modifying interfaces or altering IPs) at present are out of the scope of this project. There is rich documentation available for WireGuard in their sites, in the man command for wg, or learning from the multiple sources available online to manually understand and edit the conf file.  

Requirements  
    WireGuard  
        Install with: sudo apt install wireguard  
    UFW  
        Install with: sudo apt install ufw  
    SUDO access  

Options  
    --help  
        Get general help or command specific help  
    -v  
        visualize commands that will be ran instead of executing them  

Commands and Arguments  
    new {interface-name} [-a <address>] [-p <port>] [-f <forwarding-interface>]  
        Creates a new WireGuard interface. The command manages the creation of the configuration file, public and private keys.  
    enable {interface-name}  
    disable {interface-name}  
    enable-forwarding {interface-name} {forwarding-interface}  
    disable-forwarding {interface-name}  
    remove {interface-name}  
    peer-add {public-key <file or public key>} [-i <peer-ip>] [-p <seconds>] [-n <name or identifier>]  
        Add a new peer to the configuration file. It is heavily recommended to include a peer ip, but it can be automatically generated  
    peer-enable {-i <peer-ip> | -n <name or identifier>}  
    peer-disable {-i <peer-ip> | -n <name or identifier>}  
    peer-remove {-i <peer-ip> | -n <name or identifier>}  
