1. Make sure that you're running a FreeBSD src tree which has support
for boot profiling.
2. Add 'options TSLOG' to your kernel configuration and `make kernel`.
3. After installing new kernel, loader and rebooting, to produce an SVG:
```
sh tslog.sh > ts.log
./stackcollapse-tslog.pl < ts.log | /usr/local/bin/perl flamechart.pl -flamechart -colors tslog > tslog.svg
```
4. To get a list of the top 10 stack leaves:
```
./stackcollapse-tslog.pl < ts.log | sh supercollapse.sh | head
```
