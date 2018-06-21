#!/usr/bin/env python3

import sys
import socket
import subprocess
import argparse
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument("hostname", help="hostname to connect to")
parser.add_argument("-l", "--list", help="list vms on a host",
                    action="store_true")
parser.add_argument("-a", "--admin", help="use admin account",
                    action="store_true")
parser.add_argument("-v", "--vmname", help="enter vm name on host to connect",
                    type=str)
args = parser.parse_args()

if args.admin:
    username = "usc\\adminjpharris"
    pw = "P9wershell"
else:
    username = "usc\\jpharris"
    pw = "eyRoh.T2>dsZ?"

if args.vmname:
    vmpath = pathlib.Path("/home/harrisj/.ts/{}/{}".format(args.hostname,
                          args.vmname))
    if vmpath.is_file():
        print("Reading file {}".format(str(vmpath)))
        with open(str(vmpath), 'r') as vmguidfile:
            vmguid = vmguidfile.read().replace('\n', '')
    else:
        sys.exit("Wrong VM Name or no Guid file")

ip = socket.gethostbyname(str(args.hostname) + ".usc.internal")
cmdargs = ["xfreerdp", "/v:{}".format(ip),
        "/u:{}".format(username), "/p:{}".format(pw)]
if args.vmname:
    cmdargs.append("/vmconnect:{}".format(str(vmguid)))

result = subprocess.Popen(cmdargs)

