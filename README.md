# FreeBSD Boot Profiling  

## **Prerequisites**  
Ensure that you are running a FreeBSD source tree that supports boot profiling:  
- **FreeBSD 12-STABLE or later** (for kernel support)  
- **FreeBSD 13.1-STABLE or later** (for full loader, kernel, and rc.d tracing)  

## **Setup and Compilation**  

### 1️ **Enable TSLOG in Kernel Configuration**  
Modify your kernel configuration file (e.g., `/usr/src/sys/<Your_Architecture>/conf/<Config_File>`) and add the following line to the bottom:  
```sh
# BOOT PROFILING
options TSLOG
```

### 2️ **Enable TSLOG in Kernel Configuration** 

Run the following commands:
```
cd /usr/src
make buildkernel KERNCONF=<Config_File>
make installkernel KERNCONF=<Config_File>
```

### 3 **Reboot the system**
After installing the new kernel, reboot FreeBSD:
```
Reboot
```

## 4 **Generating a Boot Profiling Flame Graph**

Once FreeBSD has rebooted with the new kernel, run:
```
sh mkflame.sh > tslog.svg
```

This will generate a flame graph ```tslog.svg``` that visualizes the boot process.

## 5 **Optional: Analyze Boot Stack Leaves**

To get a list of the top 10 stack leaves (functions that contribute most to boot time), run:

```
sh tslog.sh > ts.log
./stackcollapse-tslog.pl < ts.log | sh supercollapse.sh | head
```

## 6 **Troubleshooting**

#### Scale parameter (```--scale```)
The scale factor adjusts the width of the output SVG.

- Lower values result in a wider flame graph.
- Higher values result in a more compressed flame graph.

```
sh mkflame.sh --scale <value> > tslog.svg
```
(Default scale is 20)

#### Unsupported platform error
Ensure your system is ```amd64```, ```x86_64```, or ```aarch64```. Other architectures may require additional configurations.
