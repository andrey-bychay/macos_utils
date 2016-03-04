#!/bin/bash
watch -n10 '(date; fdesetup status;) | tee -a ~/encryption.log'

