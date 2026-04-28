#!/bin/bash
exec ssh -o ControlMaster=no -o ControlPath=none "$@"