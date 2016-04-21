#!/bin/bash
watch -n60 '(date; fdesetup status;) | tee -a ~/encryption.log'

