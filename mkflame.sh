#!/bin/sh
sh tslog.sh |
    perl stackcollapse-tslog.pl |
    perl flamechart.pl -flamechart -colors tslog
