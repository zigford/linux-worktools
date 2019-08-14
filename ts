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
parser.add_argument("-c", "--console", help="connect to console",
                    action="store_true")
parser.add_argument("-a", "--admin", help="use admin account",
                    action="store_true")
parser.add_argument("-v", "--vmname", help="enter vm name on host to connect",
                    type=str)
parser.add_argument("-f", "--fullscreen", 
                    help="enter session in fullscreen mode", action="store_true")
parser.add_argument("-u", "--username", help="enter a custom username",
                    type=str)
parser.add_argument("-r", "--redirection",
                    help="Enable home drive redirection",
                    action="store_true")
parser.add_argument("-d", "--debug", help="enable debug output", action="store_true")
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
    if args.username:
        user = config[args.username]
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
        "/u:{}".format(username), "/p:{}".format(pw),
        "/dynamic-resolution"]
if args.console:
    cmdargs.append("/admin")
if args.vmname:
    cmdargs.append("/vmconnect:{}".format(str(vmguid)))
if args.fullscreen:
    # Attempt to get almost fullscreen by getting current resolution
    xrandrOut = subprocess.check_output(["xrandr"])
    for line in xrandrOut.splitlines():
        line = str(line)
        if "primary" in line:
            res = line.split(" ")[3].split('+')[0]
            x = res.split('x')[0]
            y = res.split('x')[1]

    if x and y:
        cmdargs.append("/h:{}".format(int(y) - 60))
        cmdargs.append("/w:{}".format(int(x)))
    else:
        cmdargs.append("/f")

if args.redirection:
    cmdargs.append("/drive:auto,*")
    cmdargs.append("/drive:home,/home/harrisj")

if args.debug:
    print("Executing {}".format(cmdargs))
    result = subprocess.Popen(cmdargs)
else:
    result = subprocess.Popen(cmdargs, stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL)

