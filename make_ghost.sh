#!/bin/bash
#===============================================================================
#
#          FILE:  make_ghost.sh
#
#         USAGE:  ./make_ghost.sh {device}
#
#   DESCRIPTION:  Backup Tool
#
#  REQUIREMENTS:  fsarchiver, partimage, fdisk, sed, grep,
#                 gdisk, ntfs-3g, lvm, awk, partclone
#
#       AUTHORS:  Dennis Anfossi, Anonymous Rabbit
#  ORGANIZATION:  ITfor s.r.l.
#       CREATED:  14/7/2013 15:33:08 CET
#       LICENSE:  GPLv2
#      REVISION:  4.2beta
#===============================================================================

function ghost {
        D_PART_TO_SAVE=`echo $1 | sed 's#/dev/##g'`
                D_PART_FS_TYPE=`blkid -s TYPE $1 | sed -n 's/[^=]*=//p' | sed 's/"//g'`
        echo "Saving partition:" ${D_PART_TO_SAVE}
        echo -n "Saving with fsarchiver.."
        fsarchiver savefs ./${D_PART_TO_SAVE}.fsa /dev/${D_PART_TO_SAVE} > /dev/null 2>&1
        if [ $? -eq 0 ] ; then
                echo -e "Done!\n"
        else        
                echo -e "Failed!\n"
                                echo "Removing temp files.."
                rm -rfv ./${D_PART_TO_SAVE}.fsa > /dev/null 2>&1
                echo -n "Saving with partimage.."
                partimage -b -d save /dev/${D_PART_TO_SAVE} ./${D_PART_TO_SAVE}
                if [ $? -eq 0 ] ; then
                        echo -e "Done!\n"
                else
                        echo -e "Failed!\n"
                                                echo -n "Removing partimage temp files.."
                        rm -rf pi* > /dev/null 2>&1
                                                echo -e "Done!\n"
                                                echo -e "Saving with parclone..\n"
                                                partclone.$D_PART_FS_TYPE -q -c -s /dev/${D_PART_TO_SAVE} -o ./${D_PART_TO_SAVE}.img
                                if [ $? -eq 0 ] ; then
                                echo -e "\nPartclone has done!\n"
                                else
                                echo -e "\nPartclone has failed!\n"
                                                        echo -n "Removing partclone temp files.."
                                #rm -rf partclone_temp_file ? > /dev/null 2>&1
                                                        echo -e "Done!\n"
                                                        echo -n "Saving with partclone.dd.."
                                                        partclone.dd -q -c -s /dev/${D_PART_TO_SAVE} -o ./${D_PART_TO_SAVE}.img.dd
                                                        echo -e "\nDone!\n"
                                                fi
                fi
        fi
}


if [ -z "$1" ]; then
         echo $"Usage: $0 {device}"
     exit 1
fi

start_time=$(date +%s)

D_DISKS=$1

D_PART_NUM=`gdisk -l $D_DISKS | grep -e '^  ' | awk '{ if ( NR > 4  ) { print } }' | awk '{print $1}'`
D_PART_TYPE=`gdisk -l $D_DISKS | grep -e '^  ' | awk '{ if ( NR > 4  ) { print } }'| awk '{print $6}'`

set -- $D_PART_NUM

dpartnumarray=( $@ )

set -- $D_PART_TYPE

dparttypearray=( $@ )

clear

# Backup GPT
echo "Backup GPT.."
D_GPT=`echo $D_DISKS | sed 's#/dev/##g'`
dd if=$D_DISKS of=./${D_GPT}.mbr count=2 bs=512 > /dev/null 2>&1
dd if=$D_DISKS of=./${D_GPT}.gpt count=34 bs=512 > /dev/null 2>&1
sgdisk $D_DISKS -b ./${D_GPT}.sg
gdisk -l $D_DISKS > ./${D_GPT}.g
sfdisk -d $D_DISKS > ./${D_GPT}.sf
parted -ms $D_DISKS print > ./${D_GPT}.parted


if [ ! ${#dpartnumarray[@]} -eq "${#dparttypearray[@]}" ]
then
        echo "Error with the arrays.. they got different size! time to die."
        exit 1
fi

i=0

while [ $i -lt ${#dpartnumarray[@]} ]
do

#                echo "${dpartnumarray[$i]} ${dparttypearray[$i]}"

D_FULL_PATH=${D_DISKS}"${dpartnumarray[$i]}"
if ! grep -q $D_FULL_PATH /proc/mounts; then        
#        echo $D_FULL_PATH "is not mounted. ok!"

# Indentify Partition(s)
        case "${dparttypearray[$i]}" in
            0700)
                        # Microsoft basic data
                        echo $D_FULL_PATH "is Microsoft basic data"
                        mkdir /mnt/${D_GPT}"${dpartnumarray[$i]}" > /dev/null 2>&1
                        ntfs-3g ${D_FULL_PATH} /mnt/${D_GPT}"${dpartnumarray[$i]}" > /dev/null 2>&1
                        rm -f /mnt/${D_GPT}"${dpartnumarray[$i]}"/{[pP]agefile,[hH]ibernate,[hH]iberfil}.sys > /dev/null 2>&1
                        umount /mnt/${D_GPT}"${dpartnumarray[$i]}" > /dev/null 2>&1
                        ghost $D_FULL_PATH
                        # action
            ;;

        0c01)
                        # Microsoft reserved
                        echo $D_FULL_PATH "is Microsoft reserved"
                        ghost $D_FULL_PATH
                        # action
            ;;

        4200)
                        # Windows LDM data
                        echo $D_FULL_PATH "is Windows LDM data"
                        # action
            ;;

        8200)
                        # Linux Swap
                        echo $D_FULL_PATH "is Linux Swap"
                        # action
            ;;

        8300)
                        # Linux filesystem
                        echo $D_FULL_PATH "is Linux filesystem"
                        ghost $D_FULL_PATH
                        # action
            ;;

        8301)
                        # Linux reserved
                        echo $D_FULL_PATH "is Linux reserved"
                        # action
            ;;

        8E00)
                        # Linux LVM
                        echo $D_FULL_PATH "is Linux LVM"
                                                echo -n "Activing.."
                        vgchange -ay > /dev/null 2>&1
                                                if [ $? -eq 0 ] ; then
                                           echo -e "Done!\n"
                                                        D_LVM=`lvdisplay | grep [pP]ath | awk '{ print $3 }'`
                                for line in $D_LVM;
                                        do
                                D_LVM_DIR=`lvdisplay | grep [vV][gG] | grep [nN]ame | awk '{ print $3 }'`
                                    for x in $D_LVM_DIR;
                                        do
                                        mkdir -p ./$x > /dev/null 2>&1
                                        done
                                 ghost $line
                                        done
                                                        echo -n "Deactivating LVM.."
                                vgchange -an > /dev/null 2>&1
                                                        if [ $? -eq 0 ] ; then
                                                                echo -e "Done!\n"
                                                        else
                                                                echo -e "Failed!\n"
                                                        fi                                                
                                else
                                                        echo -e "Failed to backup!\n"
                                                fi                        
                        # action
            ;;

        EF00)
                        # EFI System
                        echo $D_FULL_PATH "is EFI System"
                        ghost $D_FULL_PATH
                        # action
            ;;

        EF01)
                        # MBR partition scheme
                        echo $D_FULL_PATH "is MBR partition scheme"
                        # action
            ;;

        FD00)
                        # Linux RAID
                        echo $D_FULL_PATH "is Linux RAID"
                        # action
            ;;

        AF00)
                        # Apple HFS/HFS+
                        echo $D_FULL_PATH "is Apple HFS/HFS+"
                                                ghost $D_FULL_PATH
                        # action
            ;;

        *)
                        echo $D_FULL_PATH "is not supported (for now!)"
                        #exit 1
        esac
else
        echo $D_FULL_PATH "is mounted. skipped!"        
fi
####            
        i=$(($i+1))
done

# Making Checksum
echo -n Creating checksum..
find . -type f -exec md5sum {} \;>> ./${D_GPT}-checksum.md5
echo -e "Done!\n"
finish_time=$(date +%s)
min=$(( $((finish_time - start_time)) /60 ))
echo -e "\nTotal time:" $min "minutes."
