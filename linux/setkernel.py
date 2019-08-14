#!/usr/bin/env python3

import os
import argparse
import re
import sys
import fileinput

parser = argparse.ArgumentParser()
parser.add_argument("kernel", help="Kernel version to set as default")
parser.add_argument("-v", "--verbose", help="Print verbose output", 
                    action="store_true")
args = parser.parse_args()

kmenulist = []

def logVerbose(msg):
    if args.verbose:
        print(msg)

def getIndex(kernel):
    index = 0
    default = ""
    with os.popen('grub-mkconfig 2>/dev/null') as pipe:
        for line in pipe:
            if "menuentry " in line or "submenu " in line:
                m = re.match(".*(menuentry|submenu)\s'(?P<entry>.*?)'.*",
                             line.strip())
                if m is not None:
                    menu = m.group('entry')
                    if kernel in menu:
                        default += str(index)
                        logVerbose("Matched kernel: {}".format(menu))
                        return default
                    elif "Advanced" in menu:
                        default += str(index) + ">"
                        logVerbose("Drilling into submenu")
                        index = 0
                    else:
                        index += 1

def updateGrub(default):
    for line in fileinput.input('/etc/default/grub', inplace=1, backup=".bak"):
        if 'GRUB_DEFAULT' in line:
            sys.stdout.write('GRUB_DEFAULT="{}"\n'.format(default))
        else:
            sys.stdout.write(line)

### Main ###
if args.kernel == "default":
    default = 0
else:
    default = getIndex(args.kernel)
    if default == None:
        print("No matching kernel found", file=sys.stderr)
        default = "0"
    logVerbose("Updating grub with default option: {}".format(default))
    updateGrub(default)

