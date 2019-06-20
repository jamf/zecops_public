## (c) 2019 ZecOps, Inc. - https://www.zecops.com - Find Attackers' Mistakes
## iOS DFIR / MacOS DFIR tool to inspect for attacks leveraging DoubleNull (CVE-2019-XXXX) LPE
## Intended only for educational and corporate environments but NOT in commercial products unless ZecOps provide
## a written consent.
##
## Example: python cfil_collision.py test.pcap
##
## If you found a collision that happened in less than 20 seconds, on an MacOS / iPhone / iPad device, 
## it's interesting to further analyze. If the collision happened in less than 10 seconds, 
## it is highly indicative of an attack and this device is compromised.
## Please contact APTs@ZecOps.com if you observed such collision. We can assist in the rest of the investigation.
## Use at your own risk.

import socket
import struct
import sys
import dpkt
import argparse
import datetime
import logging

logging.basicConfig(level=logging.DEBUG,  
                    format='%(message)s')  
def inet_to_str(inet):
    """Convert inet object to a string

        Args:
            inet (inet struct): inet network address
        Returns:
            str: Printable/readable IP address
    """
    # First try ipv4 and then ipv6
    try:
        return socket.inet_ntop(socket.AF_INET, inet)
    except ValueError:
        return socket.inet_ntop(socket.AF_INET6, inet)


def inet_addr(addr):
    return struct.unpack("<L", socket.inet_aton(addr))[0]


def _cfil_hash(laddr, faddr, lport, fport):
    return ((faddr) ^ ((laddr) >> 16) ^ (fport) ^ (lport))


def calc_flowhash(laddr, faddr, lport, fport):
    return _cfil_hash(inet_addr(laddr), inet_addr(faddr), socket.htons(lport), socket.htons(fport))


def parse_pairs(udp_info):
    udp_pairs = []
    for line in udp_info:
        arr = line.split(',')
        if len(arr) == 4:
            udp_pair = (arr[0].strip(), arr[1].strip(),
                        int(arr[2]), int(arr[3]))
            udp_pairs.append(udp_pair)
    return udp_pairs


def read_udp_pairs_from_txt(file_path):
    '''
    each line of the txt file should be:
    "local address, remote address, local port , remote port"
    192.168.0.238,177.188.221.156,14082,18036
    '''
    with open(file_path) as ip_file:
        return parse_pairs(ip_file)
    return None

def _new_entry(ip_hashes, laddr, faddr, lport, fport, ts):
    if len(ip_hashes) == 0:
        return True
    for (laddr_p, faddr_p, lport_p, fport_p, _) in ip_hashes:
        if (laddr_p, faddr_p, lport_p, fport_p) == (laddr, faddr, lport, fport):
            continue
        else:
            return True
    return False


def calc_from_udp_dict(udp_dict):
    all_hash_dict = {}
    for ip in udp_dict:
        ip_hash_dict = {}
        for (laddr, faddr, lport, fport, ts) in udp_dict[ip]:
            flowhash = calc_flowhash(laddr, faddr, lport, fport)
            # The kernel uses gen_cnt as prefix of the sock_id, we use lport instead
            sock_id = str(lport) + ':' + hex(flowhash)
            if not sock_id in ip_hash_dict:
                ip_hash_dict[sock_id] = []

            if _new_entry(ip_hash_dict[sock_id], laddr, faddr, lport, fport, ts):
                #at least one of the laddr, faddr, lport, fport is different
                ip_hash_dict[sock_id].append((laddr, faddr, lport, fport, ts))
        all_hash_dict[ip] = ip_hash_dict
    return all_hash_dict



def calc_from_udp_pairs(udp_pairs):
    hash_dict = {}
    collision_arr = []
    for udp in udp_pairs:
        (laddr, faddr, lport, fport) = udp
        flowhash = calc_flowhash(laddr, faddr, lport, fport)
        if not flowhash in hash_dict:
            # first flowhash
            hash_dict[flowhash] = []

        if not udp in hash_dict[flowhash]:
            # at least one of the faddr,laddr,fport,lport should be different
            hash_dict[flowhash].append(udp)

        if len(hash_dict[flowhash]) > 1 and flowhash not in collision_arr:
            # new collision
            collision_arr.append(flowhash)

    return hash_dict, collision_arr


def calc_all_from_txt(file_path):
    udp_pairs = read_udp_pairs_from_txt(file_path)
    return calc_from_udp_pairs(udp_pairs)


def read_from_pcap(file_path):
    udp_dict = {}
    with open(file_path, 'rb') as f:
        pcap = dpkt.pcap.Reader(f)
        for ts, buf in pcap:
            eth = dpkt.ethernet.Ethernet(buf)
            if not isinstance(eth.data, dpkt.ip.IP) or not isinstance(eth.data.data, dpkt.udp.UDP):
                continue
            ip = eth.data
            udp = ip.data
            laddr = inet_to_str(ip.src)
            lport = udp.sport
            faddr = inet_to_str(ip.dst)
            fport = udp.dport
            if not laddr in udp_dict:
                udp_dict[laddr] = []
            udp_dict[laddr].append((laddr, faddr, lport, fport, ts))
    return udp_dict


def calc_all_from_pcap(file_path):
    udp_dict = read_from_pcap(file_path)
    return calc_from_udp_dict(udp_dict)


def collision_report(hash_dict, collision_arr):
    for flowhash in collision_arr:
        logging.INFO('collision flowhash id: {0:#x}:'.format(flowhash))
        udp_strings = ''
        for udp in hash_dict[flowhash]:
            udp_str = 'local {0:}:{2:}, remote {1:}:{3:}\n'.format(*udp)
            udp_strings += udp_str
        return udp_strings

def output_calc_min_time_span(collisions, sock_id):
    ts_arr = [ts for (laddr, faddr, lport, fport, ts) in collisions]
    ts_arr.sort()
    min_span = sys.maxsize
    collision_ts = 0
    for i in range(0, len(ts_arr)-1):
        time_span = abs(ts_arr[i] - ts_arr[i+1])
        min_span = min([time_span, min_span])
        if min_span == time_span:
            collision_ts = max([ts_arr[i], ts_arr[i+1]])

    collision_time = str(datetime.datetime.fromtimestamp(collision_ts))
    logging.info('Hash collision found, following UDP requests collided. Cfil hash: {}, collided at {}, in {} seconds'.format(sock_id, collision_time, min_span))
    for (laddr, faddr, lport, fport, ts) in collisions:
        t_str = str(datetime.datetime.fromtimestamp(ts))
        logging.info('{}:{} -> {}:{} ({})'.format(laddr, lport, faddr, fport, t_str))


def collision_report_pcap(all_hash_dict):
    collision = False
    for ip in all_hash_dict:
        per_ip = all_hash_dict[ip]
        for sock_id in per_ip:
            if len(per_ip[sock_id])>1:
                collision = True
                #calculate the time span of the collision
                output_calc_min_time_span(per_ip[sock_id], sock_id)

    if not collision:
        logging.info('No collision found.')


def main():
    parser = argparse.ArgumentParser(
        description='Process pcap, identify cfil hash collision.\n example: python cfil_collision.py test.pcap')
    parser.add_argument('-t', '--type', action='store', type=str,
                        default='pcap', help='file type, pcap or txt.')
    parser.add_argument("file", nargs=1)
    args = parser.parse_args()
    if args.type == 'pcap':
        hash_dict = calc_all_from_pcap(args.file[0])
        collision_report_pcap(hash_dict)

    elif args.type == 'txt':
        hash_dict, collision_arr = calc_all_from_txt(args.file[0])
        collision_report(hash_dict, collision_arr)

    else:
        sys.stderr.write(
            'Invalid file type, the type should be either pcap or txt.\n')
        parser.print_help(sys.stderr)
        sys.exit(2)



if __name__ == '__main__':
    main()
