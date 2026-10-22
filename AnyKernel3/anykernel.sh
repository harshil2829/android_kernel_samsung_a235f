### AnyKernel3 Ramdisk Mod Script
## For Samsung Galaxy A23 (SM-A235F) - KernelSU & RTDev Custom Kernel
## Configured for osm0sis AnyKernel3

### AnyKernel setup
# global properties
properties() { '
kernel.string=KernelSU + RTDev Kernel for Samsung Galaxy A23 (SM-A235F)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=a23
device.name2=a235f
device.name3=SM-A235F
device.name4=bengal
device.name5=khaje
supported.versions=12, 13, 14
'; } # end properties

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
split_boot;

flash_boot;
## end boot install
