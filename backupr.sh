#!/bin/bash
#
# Module     : backupr.sh
# Author     : Jeff Holmes
# Created on : 07/02/14
# Version    : 6.0
#
# Purpose: Bash shell scriBp to bckup files and directories using rsync.
#
# Comments:
#
# Usage:
#
# References:
#
# History:
# Date     Programmer        Description
# -------- ----------------- -------------------------------------
#

shopt -o -s nounset     #  disallow use of undefined variables

declare -r SCRIPT="$(basename $0)"   # save script name


# declare -r BACKUP="/media/WD1600JD/Backup/bash"
declare -r BACKUP="/media/WIN_SYS3/Backup"
declare -r BACKUP_MAIL="/media/WIN_SYS5/Backup/evolution"

declare -r MYPASSPORT="/media/my_passport"

declare -r ITUNES="/media/WIN_SYS6/iTunes/"
declare -r ITUNES_BACKUP="/media/WIN_SYS3/Music"

declare -r THUNDERBIRD="/media/WIN_SYS6/Thunderbird"
# declare -r THUNDERBIRD_BACKUP="/media/my_passport/Backup"


declare -r LOGFILE="$HOME/log/backupr.log"

declare -r DIRLIST=( "Box Sync" "Dropbox" "My Tresors" "Thunderbird" "Ubuntu" )

# declare -r DIRLIST=( "bash" "dev" "perl" )
# declare -r DIRLIST=( "Documents" "Dropbox" "KeePass" "Music" "Pictures" "Ubuntu" )

# Remove log file if it already exists
# if [ -e $LOGFILE ]; then
#     rm $LOGFILE
# fi

# declare -i ERRORS=0   # false
# declare -i RETVAL=0


source "logger.sh"          # libray for logging


#
# Sync the folders SRC and DEST using rsync.
#
sync() {

    local src="$1"
    local dest="$2"

    printf "\n" >> $LOGFILE   # print blank lines to LOGFILE

    # print_log "sync: Syncing $src with $dest ..."
    # printf "\n" >> $LOGFILE   # print blank lines to LOGFILE

    # rsync -aLprtuvz --delete --progress --stats --log-file="$LOGFILE" "$src"  "$dest"
    rsync -aLvz --delete --progress --stats --log-file="$LOGFILE" "$src"  "$dest" || \
    (printf "sync: Unable to execute rsync command" && exit 1)

    # Check for errors
    # RETVAL=$?  # Save for calling routine
    if [ $? -ne 0 ]; then
        # display message and continue.
        msg="$SCRIPT: sync(): error occurred processing $src -- see $LOGFILE"
        print_log "$msg"
        printf "sync: Unexpected error with rsync command\n"
        exit 1
    fi

    return 0    # success

}  # sync()


#
# Sync folder from SRC to DEST.
#
sync_folder() {

    local src="$1"
    local dest="$2"

    # Print blank lines and header to LOGFILE and terminal
    printf "\n\n====================================\n" >> $LOGFILE
    printf "\n\n====================================\n"

    print_log "sync_folder: Syncing $src w1ith $dest ..."

    sync "$src" "$dest"  || exit 1

    return 0    # success

}  # sync_folder()


#
# Sync folders from SRC to DEST whose name is given in @DIRLIST.
#
sync_home() {

    local src="$1"    # $HOME
    local dest="$2"   # $BACKUP
    local x="$HOME"
    local ucase=""

    # Print blank lines and header to LOGFILE and terminal
    printf "\n\n====================================\n" >> $LOGFILE
    printf "\n\n====================================\n"

    print_log "sync_home: Syncing $src with $dest ..."

    for i in ${DIRLIST[@]}; do
        ucase=$(echo $i | tr '[a-z]' '[A-Z]')  # convert to uppercase
        if [ "$ucase" != "THUNDERBIRD" ]; then
            x="$src/$i"
            sync "$x" "$dest"  || exit 1
        fi
    done

    return 0  # success

}  # sync_home()



# Create file fldr.tar.gz in directory "SRC/YYYYMMDD"
# and display progressbar while compressing file.
# NOTE: Seems to be a problem if filename has a non-alpha character.
tar_folder() {

    local src="$1"
    local dest="$2"
    local dname="$(dirname $src)"   # directory name
    local fname="$(basename $src)"  # file/folder name
    local dt=$(date +'%Y%m%d')      # YYYYMMDD
    local fpath="$dest/$dt/$x.tar.gz"

    # tar_folder "$dest/$x" "$dest/$dt"
    cd "$dest"  || (printf "tar_folder: Unable to cd to $dest" && exit 1)

    # Remove tar.gz file if it already exists
    if [ -f "$fpath" ]; then
        rm "$fpath" || (printf "backup_folders: Unable to rm $fpath\n" && exit 1)
    fi

    # tar -zcvf file.tar.gz -C $path $fname  || return 1

    # Create tar.gz in folder named YYYYMMDD and display progressbar while compressing file.
    # (pv -n backup.tar.gz | tar -zcf "BACKUP/YYYYMMDD/Documents.tar.gz " -C "BACKUP" "Documents" ) 2>&1 | dialog --gauge "Running tar, please wait..." 10 70 0

    # cd $src || return 1
    # tar cf - Documents | pv -s `du -sb Documents | grep -o '[0-9]\+' | grep -v '1600'` -N tar | gzip > ./20150517/Documents.tar.gz || return 1

    # echo "src: $src"
    # echo "dest: $dest"
    # echo "dname: $dname"
    # echo "fname: $fname"
    # echo "fpath: $fpath"

    cd $dname  || (printf "tar_folder: unable to cd to $dname" && exit 1)

    tar zcvf - $fname | pv -s $(du -sb $fname | grep -o '[0-9]\+') -N tar | \
    gzip > $dname/$dt/$fname.tar.gz

    if [ $? -ne 0 ]; then
        printf "tar_folder: Unable to tar folder: $fname\n"
        exit 1
    fi

    return 0    # success

}  # tar_folder()


#
# Backup folders in SRC to tar.gz files (names of folders given in @DIRLIST).
#
backup_home() {

    local dest="$1"             # $BACKUP
    local dt=$(date +'%Y%m%d')  # YYYYMMDD
    local dname=""              # directory
    local x=""
    local fpath=""

    # Print blank lines and header to LOGFILE and terminal
    printf "\n\n====================================\n" >> $LOGFILE
    printf "\n\n====================================\n"

    print_log "backup_home: Archiving key folders in $dest to $dest/$dt ..."
    printf "\n" >> $LOGFILE

    # Change to $dest
    cd $dest  || (printf "backup_home: Unable to cd to $dest\n" && exit 1)

    # Remove folder "YYYYMMDD" if it already exists
    if [ -d "$dt" ]; then
        rm -rf $dt || (printf "backup_home: Unable to rm $dt\n" && exit 1)
    fi

    # Create folder "YYYYMMDD"
    mkdir $dt || (printf "backup_home: Unable to mkdir to $dt\n" && exit 1)
    cd $dt  || (printf "backup_home: Unable to cd to $dt\n" && exit 1)

    # Loop thru each folder name given in @IRLIST
    for x in ${DIRLIST[@]}; do

        # Add destination directory and date to filename:
        # e.g. BACKUP/YYYYMMDD/$x.tar.gz
        fpath="$dest/$dt/$x.tar.gz"
        dname="$(basename $dest)"

        print_log "backup_home: Archiving folder $dname/$x ..."

        # Create $x.tar.gz
        tar_folder "$dest/$x" "$dest/$dt" || exit 1

    done

    return 0    # success

}  # backup_home()


# Create file fname.YYYYMMDD.tar.gz in current directory (SRC)
# and display progressbar while compressing file.
# NOTE: Seems to be a problem if filename has a non-alpha character.
tar_music_pics() {

    local src="$1"
    local dname="$(dirname $src)"   # directory name
    local fname="$(basename $src)"  # file/folder name
    local dt=$(date +'%Y%m%d')      # YYYYMMDD

    cd "$src"  || \
    (printf "tar_music_pics: Unable to cd $src\n" && exit 1)

    # Remove file if it already exists
    if [ -f "$fname.tar.gz" ]; then
        rm -rf "$fname.tar.gz" || \
        (printf "tar_music_pics: Unable to test and rm $fname.tar.gz\n" && exit 1)
    fi

    cd $dname  || \
    (printf "tar_music_pics: Unable to cd $dname\n" && exit 1)

    tar cf - $fname | pv -s $(du -sb $fname | grep -o '[0-9]\+') -N tar | \
    gzip > $dname/$fname.$dt.tar.gz

    if [ $? -ne 0 ]; then
        printf "tar_music_pics: Unable to tar $fname\n"
        exit 1
    fi

    return 0    # success

}  # tar_music_pics()


#
# Backup the "Music" and "Pictures" folders in SRC to tar.gz files.
#
backup_music_pics() {

    local src="$1"                  # $BACKUP
    local dt=$(date +'%Y%m%d')      # YYYYMMDD
    local dname="$(dirname $src)"   # directory
    local fname="$(basename $src)"  # folder
    local x=""

    # Print blank lines and header to LOGFILE and terminal
    printf "\n\n====================================\n" >> $LOGFILE
    printf "\n\n====================================\n"

    #
    # Backup Music folder
    #
    x="Music.$dt.tar.gz"

    print_log "backup_music_pics: Archiving folder $fname/$x to $fname/$x ..."

    # Remove tar.gz file if it already exists
    if [ -f "$x" ]; then
        rm "$x" || \
        (printf "backup_music_pics: Unable to test and rm $x\n" && exit 1)
    fi

    # Create Music.tar.gz
    tar_music_pics $src/$x || exit 1


    #
    # Backup Pictures folder
    #
    x="Pictures.$dt.tar.gz"

    print_log "backup_music_pics: Archiving folder $fname/$x ..."

    # Remove tar.gz file if it already exists
    if [ -f "$x" ]; then
        rm "$x" ||  \
        (printf "backup_music_pics: Unable to test and rm $x\n" && exit 1)
    fi

    # Create Pictures.tar.gz
    tar_music_pics $src/$x || exit 1

    return 0    # success

}  # backup_music_pics()


#
# Copy files from src to dest.
#
copy_files() {

    local src="$1"              # $BACKUP
    local dest="$2"             # $COPY
    local dt=$(date +'%Y%m%d')  # YYYYMMDD
    local dname=""              # directory
    local fname=""              # folder

    # Print blank lines and header to LOGFILE and terminal
    printf "\n\n====================================\n" >> $LOGFILE
    printf "\n\n====================================\n"

    print_log "copy_files: Copying $src/$dt to $dest/$dt ..."


    # Change to destination directory
    cd $dest  || \
    (printf "copy_files: unable to cd to $dest\n" && exit 1)

    # if it already exists, remove "YYYYMMDD" folder
    if [ -d "$dt" ]; then
        rm -rf "$dt" || \
        (printf "copy_files: Unable to rm $dest/$dt\n" && exit 1)
    fi


    # Create folder named "YYYYMMDD"
    mkdir $dt || (printf "copy_files: unable to mkdir $dt\n" && exit 1)
    cd $dt  || (printf "copy_files: unable to cd $dt\n" && exit 1)


    # Copy files in $src/YYYMMDD to $dest/YYYYMMDD directory.
    # Process list of files created using globbing.
    for x in /$src/$dt/*; do
        # Extract filename from path
        fname="$(basename $x)"

        # Copy all files except Dropbox.tar.gz.
        # if [[ "$fname" != "Dropbox.tar.gz" ]]; then
        # fi

        print_log "copy_files: Copying $fname ..."

        gcp -v "$src/$dt/$fname" "$dest/$dt/$fname"

        if [ $? -ne 0 ]; then
            printf "copy_files: Unable to gcp $src/$dt/$fname $dest/$dt/$fname\n"
            exit 1
        fi
    done

    return 0    # success

}  # copy_files()



#
# Main program
#

{

    declare SRC=""
    declare DEST=""

    # declare -r SCRIPT=${0##*/}    # read-only variable

    if [ $# -ne 1 ]; then
        echo "Usage: $SCRIPT [ sync | home | copy | music | all ]"
        exit 1
    fi

    if [ "$1" != "sync" ] && [ "$1" != "home" ] && [ "$1" != "copy" ] && [ "$1" != "music" ] && [ "$1" != "all" ]; then
        echo "Usage: $SCRIPT [ sync | home | copy | music | all ]"
        exit 0
    fi


    # Check for problems clearing LOGFILE
    if ! truncate_log "$LOGFILE" ; then
        echo "$LOGFILE not found"
        exit 1
    fi


    #
    # Sync key folders to Backup folder.
    #

    if [ "$1" == "sync" ] || [ "$1" == "all" ]; then

        # Sync iTunes folder to ITUNES_BACKUP.
        sync_folder "$ITUNES/" "$ITUNES_BACKUP" || \
        (printf "main: Unable to sync_folder $ITUNES $ITUNES_BACKUP\n" && exit 1)

        # Sync Thunderbird folder to THUNDERBIRD_BACKUP.
        sync_folder "$THUNDERBIRD" "$BACKUP" || \
        (printf "main: Unable to sync_folder $THUNDERBIRD $THUNDERBIRD_BACKUP\n" && exit 1)

        # Sync folders in @DIRLIST to BACKUP.
        sync_home "$HOME" "$BACKUP" || \
        (printf "main: Unable to sync_home $HOME $BACKUP\n" && exit 1)

    fi


    #
    # Backup folders given in @DIRLIST to tar.gz files
    #

    if [ "$1" == "home" ] || [ "$1" == "all" ]; then
        backup_home "$BACKUP" || \
        (printf "main: Unable to backup_folders $BACKUP\n" && exit 1)
    fi


    #
    # Sync Music and Pictures to external drive.
    #

    if [ "$1" == "music" ]; then

        # Backup Music and Pictures to tar.gz files.
        # backup_music_pics "$BACKUP" ||  \
        # (printf "main: Unable to backup_music_pics $BACKUP\n" && exit 1)

        # Sync Music to my_passport drive.
        sync_folder "$ITUNES/", "$MYPASSPORT/Music" || \
        (printf "main: Unable to sync_folder $ITUNES $MYPASSPORT/Music\n" && exit 1)

        # Sync Pictures to my_passport drive.
        sync_folder "$PICTURES", "$MYPASSPORT" || \
        (printf "main: Unable to sync_folder $PICTURES $MYPASSPORT\n" && exit 1)

    fi


    #
    # Copy files to MYPASSPORT.
    #

    if [ "$1" == "copy" ] || [ "$1" == "all" ]; then

        declare dt=$(date +'%Y%m%d')      # YYYYMMDD
        declare fname=""

        # Copy backup of @DIRLIST to COPY.
        # copy_files "$BACKUP" "$COPY" || \
        # (printf "main: Unable to copy_files $BACKUP $COPY\n" && exit 1)


        # Copy evolution-backup-YYYYMMDD.tar.gz to $COPY/evolution
        # fname="evolution-backup-$dt.tar.gz"
        # if [ -f "$BACKUP_MAIL/$fname" ]; then
        #     gcp -fv "$BACKUP_MAIL/$fname" "$dest/evolution" || \
        #     (printf "main: Unable to gcp $BACKUP_MAIL/$fname $COPY\n" && exit 1)
        # fi


        # Copy Music.YYYYMMDD.tar.gz
        fname="Music.$dt.tar.gz"
        if [ -f "$BACKUP/$fname" ]; then
            gcp -fv "$src/$fname" "$MYPASSPORT/Backup" || \
            (printf "main: Unable to gcp $BACKUP/$fname $MYPASSPORT/Backup\n" && exit 1)
        fi

        # Copy Pictures.YYYYMMDD.tar.gz
        fname="Pictures.$dt.tar.gz"
        if [ -f "$BACKUP/$fname" ]; then
            gcp -fv "$src/$fname" "$MYPASSPORT/Backup" || \
            (printf "main: Unable to gcp $BACKUP/$fname $MYPASSPORT/Backup\n" && exit 1)
        fi

    fi


    # Let user know script finished successfully.
    if [ $? -eq 0 ]; then
        printf "\n" >> $LOGFILE
        print_log "$SCRIPT completed successfully."
    fi

}

exit 0  # All is well
