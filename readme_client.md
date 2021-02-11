Definition
    client_wg-config: fast client configuration generation for wireguard

Syntax  
    bash client_wg-config.sh [options] <command> <arguments> [optional arguments]  

Requirements
    Wireguard for key generation
    qrencode for generating QR images of the configuration file
    zip for creating zipped files of the configuration file
    SUDO access ONLY for the new-push command
    wg-config.sh in the same directory ONLY for the new-push command

Options  
    -h|--help  
        Get general help or command specific help  

Commands and arguments
    new {<client-ip-address>} {<server endpoint:port>} {-f <server-pubkey-file> | -k <server-pubkey>} [-z <zip-conf> | -q <qr-conf> | -c <conf-file>] [-d <dns>] [-a <allowed-ips>] [-s <save-pubkey>] [-p <keepalive-seconds>]  
        Create a new client configuration file. It requires the server endpoint or address, as -e, and its public key (can be provided as a file). From the client side it requires an IP to get assigned on connection (the same the server configures).
        The zip-, qr- and file-conf determine the format of the configuration file and a name. If not given the file contents will be displayed in the terminal alongside with a QR of the conf file.
        The DNS configuration default is "1.1.1.1, 8.8.8.8", but if it is provided and left empty the client will have DNS preferences disabled.
        Allowed IPs determine which connections will be routed through the tunnel. Default is 0.0.0.0/0 which routes everything, including internet connectivity. The server requires to have forwarding enabled for this.
        Save publickey saves it as standalone in a given filename.
        Keepalive seconds makes the client send data to the server at least every given seconds. Default is disabled.
        All default values from optional parameters are listed at the beggining of the script and can be changed.
    new-push {<interface-name>} {<client-ip-address>} {<server endpoint:port>} [-z <conf-zip> | -q <qr-conf> | -c <file-conf>] [-d <dns>] [-a <allowed-ips>] [-s <save-pubkey>] [-p <keepalive-seconds>] [-n <name>]  
        Same as the new command but if executed in the server it will add the peer automatically to the given interface. It requires having the wg-config.sh file in the same directory.
        Optional argument name gives the peer an identifier in the server config.  
