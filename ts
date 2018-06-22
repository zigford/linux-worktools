#!/usr/bin/env python3

import sys
import socket
import subprocess
import argparse
import pathlib
import configparser
import os

parser = argparse.ArgumentParser()
parser.add_argument("hostname", help="hostname to connect to")
parser.add_argument("-a", "--admin", help="use admin account",
                    action="store_true")
parser.add_argument("-v", "--vmname", help="enter vm name on host to connect",
                    type=str)
parser.add_argument("-f", "--fullscreen", 
                    help="enter session in fullscreen mode", action="store_true")
args = parser.parse_args()

config = configparser.ConfigParser()
home = pathlib.Path(os.environ['HOME'])
cDir = home.joinpath('.ts')
cFile = cDir.joinpath('ts.ini')
config.read(str(cFile))
if not config.sections():
    sys.exit("Failed to read config")

defuser = config['DEFAULT']['user']
if args.admin:
    user = config[config['DEFAULT']['admin']]
else:
    user = config[config['DEFAULT']['user']]

username = user['domain'] + '\\' + user['username']
pw = user['password']

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
cmdargs = ["xfreerdp", "/v:{}".format(ip), "/cert-tofu", 
        "/u:{}".format(username), "/p:{}".format(pw)]
if args.vmname:
    cmdargs.append("/vmconnect:{}".format(str(vmguid)))
if args.fullscreen:
    cmdargs.append("/f")

result = subprocess.Popen(cmdargs)

