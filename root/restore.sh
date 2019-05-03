#!/bin/sh
#
# Name:          restore.sh
# Description:   A script which auto-install Shadowsocks proxy.
# Version:       0.1
# Date:          2017-10-18
# Author:        leamtrop
# Website:       https://github.com/leamtrop

usage() {
cat <<EOF
Usage: sh restore.sh [options]
Valid options are:
    -e --execute
        Run script without options
    -d, --dns <dns_ip>
        DNS IP address for the ChinaList Domains (Default: 114.114.114.114)
    -p, --port <dns_port>
        DNS Port for the ChinaList Domains (Default: 53)
    -c, --current <current_version>
        The installed LEDE version (Default: 18.06.2)
    -h, --help  Usage
EOF
    exit $1
}

clean_and_exit() {
    # Clean up temp files
    printf 'Cleaning up...'
    rm -rf /etc/chinadns_chnroute.txt-opkg
    rm -rf /etc/dnsmasq.conf-opkg
    rm -rf /etc/config/shadowsocks-opkg
    rm -rf /etc/config/chinadns-opkg
    rm -rf /etc/config/dhcp-opkg
    rm -rf /etc/config/dns-forwarder-opkg
    rm -rf /etc/config/dhcp-opkg
    rm -rf /overlay/upper/etc/dnsmasq.conf-opkg
    printf ' Done.\n\n'
    exit $1
}

check_files() {
    # Check file
    FILE='shadowsocks-libev_3.1.3-1_mipsel_24kc.ipk'
    if [ ! -f ./ipk/${FILE} ]; then
        printf '\033[31mError: Missing Files.\nPlease check whether you have the following'
        exit 3
    fi
}

get_args() {
    DNS_IP='114.114.114.114'
    DNS_PORT='53'
    VERSION='18.06.2'

    while [ ${#} -gt 0 ]; do
        case "${1}" in
            --execute | -e)
                ;;
            --help | -h)
                usage 0
                ;;
            --dns | -d)
                DNS_IP="$2"
                shift
                ;;
            --port | -p)
                DNS_PORT="$2"
                shift
                ;;
            --current | -c)
                VERSION="$2"
                shift
                ;;
            *)
                echo "Invalid argument: $1"
                usage 1
                ;;
        esac
        shift 1
    done
}

process() {
    # Configurate opkg source list
    # sed -i -E "s/(\d{2}.)(\d{2}.)(\d{1})/${VERSION}/g" /etc/opkg/distfeeds.conf

    # Install packages
    printf 'Install packages...\n\n'
    opkg update
    opkg install luci-i18n-base-zh-cn
    opkg install ip-full ipset iptables-mod-tproxy libev libpthread libpcre libmbedtls
    opkg install ./ipk/*.ipk
    printf 'Done.\n\n'

    # Configurate dnsmasq
    printf 'Set dnsmasq...\n\n'
    DIRECTORY='/etc/dnsmasq.d'
    if [ ! -d "${DIRECTORY}" ]; then
        # Control will enter here if $DIRECTORY doesn't exist.
        mkdir ${DIRECTORY}
    fi
    if ! uci show | grep "confdir='/etc/dnsmasq.d'"; then
        # Control will enter here if confdir doesn't exist.
        uci add_list dhcp.@dnsmasq[0].confdir=/etc/dnsmasq.d
        uci commit dhcp
    fi
    opkg install coreutils-base64 ca-certificates ca-bundle curl librt openssl-util
    opkg remove dnsmasq && opkg install dnsmasq-full
    printf 'Done.\n\n'

    # Configurate ChinaList
    printf 'Set ChinaList...\n\n'
    curl -L -o generate_dnsmasq_chinalist.sh https://github.com/cokebar/openwrt-scripts/raw/master/generate_dnsmasq_chinalist.sh
    chmod +x generate_dnsmasq_chinalist.sh
    sh generate_dnsmasq_chinalist.sh -d ${DNS_IP} -p ${DNS_PORT} -s ss_spec_dst_bp -o /etc/dnsmasq.d/accelerated-domains.china.conf
    echo -e "#server=/example.com/${DNS_IP}\n#ipset=/example.com/ss_spec_dst_bp" > /etc/dnsmasq.d/custom_bypass.conf
    printf 'Done.\n\n'

    # Configurate GFWList
    printf 'Set GFWList...\n\n'
    curl -L -o gfwlist2dnsmasq.sh https://github.com/cokebar/gfwlist2dnsmasq/raw/master/gfwlist2dnsmasq.sh
    chmod +x gfwlist2dnsmasq.sh
    sh gfwlist2dnsmasq.sh -d 127.0.0.1 -p 5300 -s ss_spec_dst_fw -o /etc/dnsmasq.d/dnsmasq_gfwlist.conf
    echo -e "#server=/example.com/127.0.0.1#5300\n#ipset=/example.com/ss_spec_dst_fw" > /etc/dnsmasq.d/custom_forward.conf
    printf 'Done.\n\n'

    # Restart
    /etc/init.d/dnsmasq restart

    # Clean up
    clean_and_exit
}

main() {
    if [ -z "$1" ]; then
        usage 0
    else
        check_files
        get_args "$@"
        process
    fi
}

main "$@"
