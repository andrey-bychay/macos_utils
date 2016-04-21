#!/bin/bash
tail -fn300 ~/encryption.log | ./render_progress.pl $@

