#!/bin/bash

dd if=/dev/xvda of=/dev/null bs=1M </dev/null &>/dev/null &
disown -a
