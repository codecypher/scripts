#!/usr/bin/perl
#
# Module     : backup.pl
# Author     : Jeff Holmes
# Created on : 07/02/14
# Version    : 5.0
#
# Purpose: Perl script to ackup files and directories using rsync
#
# Comments:
#
#  Runs on Linux and MinGW (Msys) on Windows
#
#  Unable to show output of commands to log file for debugging issues.
#  Using capturex works but doesn't show progress of command.
#
# Usage:
#
# References:
#
# History:
# Date     Programmer        Description
# -------- ----------------- -------------------------------------
# 01/05/16 Jeff              First fully functional version.
#



use strict;           # disallow use of undefined variables
# use warnings;

# use local::lib;

use Archive::Tar;
use File::Basename;
use File::Copy;
use File::Find;
use File::Path;
use File::Rsync;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use IPC::System::Simple qw( capture capturex system systemx run runx $EXITVAL EXIT_ANY );


my ($HOME, $LOGFILE, $PROGNAME);
my ($WINSYS2, $WINSYS3, $MYPASSPORT, $WINPROFILE);
my ($BACKUP, $BACKUP_MAIL, $ITUNES, $ITUNES_BACKUP, $PICTURES, $MYPASSPORT);
my ($THUNDERBIRD, $THUNDERBIRD_BACKUP, $COPY);

my @DIRLIST = ( "Box Sync", "Documents", "Dropbox", "My Tresors" );

# =============================================================
#  Helper Functions
# =============================================================

# Truncate and/or create log file
sub truncate_log {

    my ($filename) = @_;
    my $encoding = ":encoding(UTF-8)";
    my $handle = undef;

    open($handle, "> $encoding", $filename) or die "truncate_log: Can't open $filename for appending: $!";
    printf($handle "") or die "truncate_log: Error writing to $filename: $!";
    close($handle) or die "truncate_log: Error closing $filename: $!";

    return 0;   # success

}  # truncate_log()


# Get formatted timestamp as string: YYYYMMDD-HH:MM:SS.
sub get_timestamp {

    my $timestamp = "";

    eval {
        $timestamp = capturex(EXIT_ANY, 'date', '+%Y%m%d-%H:%M:%S');
        if ($EXITVAL) {
            die "get_timestamp: capturex exited with value $EXITVAL\n";
        } else {
            chomp($timestamp);
        }
    };

    # if error occured, terminate program.
    if ($@) {
        die "get_timestamp: capturex unable to run command: $@";
    }

    return $timestamp;     # success

}  # get_timestamp()


# Get formatted date as string: YYYYMMDD
sub get_date {

    my $datestring = "";

    eval {
        $datestring = capturex(EXIT_ANY, 'date', '+%Y%m%d');
        if ($EXITVAL) {
            die "get_date: capturex exited with value $EXITVAL\n";
        } else {
            chomp($datestring);
        }
    };

    # if error occured, terminate program.
    if ($@) {
        die "get_date: capturex unable to run command: $@";
    }

    return $datestring;     # success

}  # get_date()


# Append message to logfile.
sub log_msg {

    my ($msg) = @_;    # Message to log

    open(LOG, ">>$LOGFILE") or die "Error opening $LOGFILE: $!";
    printf(LOG "%s\n", $msg) or die "Error writing to $LOGFILE: $!";
    close(LOG) or die "Error closing $LOGFILE: $!";

}  # log_msg()


# Append message with timestamp to logfile.
sub log_msg_timestamp {

    my ($msg) = @_;    # Message to log
    my $timestamp = "";

    $timestamp = get_timestamp();

    $msg = get_timestamp() . " $msg";

    open(LOG, ">>$LOGFILE") or die "Error opening $LOGFILE: $!";
    printf(LOG "\n%s\n", $msg) or die "Error writing to $LOGFILE: $!";
    close(LOG) or die "Error closing $LOGFILE: $!";

}  # log_msg_timestamp()


# Display formatted message to STDOUT
sub print_msg {

    my ($msg) = @_;
    my $timestamp = get_timestamp();

    $msg =  get_timestamp() . " $msg";
    printf "\n%s\n", $msg;    # Print message with timestamp

}  # print_msg()


# Print formatted message to LOGFILE
sub print_log {

    my ($msg) = @_;

    print_msg $msg;    # Print message to stdout

    log_msg_timestamp $msg;      # Print message to logfile

}  # print_log()

# =============================================================
# End Helper Function
# =============================================================


# =============================================================
# Core Functions for program
# =============================================================

#
# Use an anonymous pipe to pipe output of rsync to this program
# so we can display it.
#
# 6 rsync Examples to Exclude Multiple Files and Directories using exclude-from
# http://www.thegeekstuff.com/2011/01/rsync-exclude-files-and-folders/
sub run_rsync {

    my ($src, $dest) = @_;

    # Add trailing slash
    # if ($src !~  m#.*/$#) { $src .= "/"; }
    # if ($dest !~  m#.*/$#) { $dest .= "/"; }

    print_log "run_rsync: Syncing $src to $dest\n";

    # my $run_pgm = "rsync -aLprtuvz --delete --progress --stats --log-file='$LOGFILE' '$src' '$dest'";
    my $run_pgm = "rsync -aLprtuz --exclude-from 'backup-exclude-list.txt' --delete --progress --stats --log-file='$LOGFILE' '$src' '$dest'";

    open(FH, "$run_pgm |") or die "run_rsync: Couldn't start rsync: $!\n";
    while (<FH>) {
        print $_;
    }
    close FH or die $! ? "run_rsync: Error closing rsync pipe: $!\n"
                       : "run_rsync: Exit status $? from closing rsync\n";

    # if (close FH) {
    #     return 0;
    # } else {
    #     if ($!) {
    #         print_log "run_rsync: Error closing rsync pipe: $!\n";
    #         return 1;
    #     } else {
    #         print_log "run_rsync: Exit status $? from rsync\n";
    #         return 1;
    #     }
    # }


    return 0;   # success

}  # run_rsync()


#
# Sync the given directories using rsync.
#
sub sync_folder {

    my ($src, $dest) = @_;
    my $rtn = 0;

    $rtn = run_rsync  "$src", "$dest";

    # If error occurs print message and exit program.
    if ($rtn) {
        print_log "sync_folder: Unexpected error syncing $src to $dest\n";
        exit 1;
    }

    return 0;   # success

}  # sync_folder()


#
# Sync folders from in HOME directory given in @DIRLIST.
#
sub sync_home {

    my ($src, $dest) = @_;
    # my $basename = basename $LOGFILE;
    my ($x, $rtn) = ("", 0);

    log_msg "";  # print blank line to log
    print_log "sync_home: Syncing folders in $src to $dest";

    # Loop thru folder list syncing each folder to $dest
    foreach $x (@DIRLIST) {

        # sync all folders in @DIRLIST except Thunderbird
        #if ( uc $x ne "THUNDERBIRD") {
        #    $rtn = sync_folder "$src/$x", "$dest";
        #}

        # sync all folders in @DIRLIST
        $rtn = sync_folder "$src/$x", "$dest";

        # exit loop if an error occurs
        if ($rtn) {
            print "sync_home: Unexpected error syncing $src/$x with $dest: $!\n";
            exit 1;
        }
    }

    # # Provide feedback to user
    # print_log "sync_home completed successfully.";

    return 0;   # success

}  # sync_home()


#
# Use an anonymous pipe to pipe output of tar to
# this program so we can display it.
#
sub run_tar {

    my ($src, $dest) = @_;

    # Add trailing slash
    # if ($src !~  m#.*/$#) { $src .= "/"; }
    # if ($dest !~  m#.*/$#) { $dest .= "/"; }

    # print_log "run_tar: Processing $src $dest\n";

    # src: "$WINSYS3/Backup/Box Sync"
    # dest: "$WINSYS3/Backup/YYYYMMDD"
    # filename: "Box Sync"
    # dirname: "$WINSYS3/Backup/"
    # suffix: ""
    my($srcfilename, $srcdirname, $srcsuffix) = fileparse($src, ".tar.gz");

    # fname: "Box Sync.tar.gz"
    # filepath: "$WINSYS3/Backup/YYYYMMDD/Box Sync.tar.gz"
    my $filename = $srcfilename . ".tar.gz";
    my $filepath = $dest . "/$filename";

    # print "src: $src dest: $dest filepath: $filepath\n";
    # print "filename: $filename dirname: $srcdirname suffix: $srcsuffix\n";

    # Remove tar.gz file if it already exists
    if (-e "$filepath") {
        unlink "$filepath" or die "run_tar: unable to delete $filepath: $!\n";
    }

    # chdir to WINSYS3/Backup/ folder
    chdir "$srcdirname" or die "run_tar: cannot chdir to $srcdirname: $!\n";

    my $run_pgm = "tar zcfh '$filepath' '$srcfilename/'";

    # calculate folder size in MB
    #my $size = get_size($src);
    #$size = $size/1000/1000;
    #printf "size: %7.2f MB\n", $size;

    open(FH, "$run_pgm |") or die "run_tar: Could not run tar: $!\n";
    while (<FH>) {
        print $_;
    }
    close FH or die $! ? "run_tar: Error closing tar pipe: $!\n"
                       : "run_tar: Exit status $? from closing tar\n";

    return 0;   # success

}  # run_tar()


# get folder size
sub get_size {

    my ($src) = @_;
    my $size = 0;

    find(sub { $size += -s if -f $_ }, "$src");

    return $size;
}

#
# Backup key folders in DEST to tar.gz and place in folder YYYYMMDD
#
sub backup_home {

    my ($dest) = @_;
    my ($x, $dname) = ("", "");

    my $dt = get_date();    # YYYYMMDD
    my $val = "";

    log_msg "";  # print blank line to log
    print_log "backup_home: Archiving key folders in $dest to $dest/$dt";

    # Remove directory YYYYMMDD
    # Need to exit script or encounter error with mkdir.
    if (-e "$dest/$dt") {
        rmtree "$dest/$dt" or die "backup_home: Unable to rm $dest/$dt: $!\n";
        print "\nbackup_home: rmtree $dest/$dt completed. Need to restart script.";
        exit 0;

    }

    # Create backup directory
    my $permissions = "0755";
    mkdir "$dest/$dt", oct($permissions) or die "backup_home: Unable to create $dest/$dt: $!\n";

    # Loop thru folder list compressing each folder to $dest
    foreach $x (@DIRLIST) {
        print_log "backup_home: Archiving folder $dest/$x ...";
        run_tar "$dest/$x", "$dest/$dt";
    }

    return 0    # success

}  # backup_home()


#
# Backup to thumb drive.
#
sub backup_usb {

    my $basename = basename $LOGFILE;

    # Copy folders from HOME to Thumb Drive.
    my @dirlist = ( "Documents", "Pictures", "Private" );
    my $src = "/home/username";
    my $dest="/media/username/Emtec32";
    backup_list $src, $dest, @dirlist;

    print_log "Backup completed successfully.\n";

    return 0;   # success

}  # backup_usb()


#
# Use an anonymous pipe to pipe output of tar to this program
# so we can display it.
#
sub run_gcp {

    my ($src, $dest) = @_;

    my $run_pgm = "gcp -fv '$src' '$dest'";

    open(FH, "$run_pgm |") or die "run_gcp: Couldn't start gcp: $!\n";
    while (<FH>) {
        print $_;
    }
    close FH or die $! ? "run_gcp: Error closing gcp pipe: $!\n"
                       : "run_gcp: Exit status $? from closing gcp\n";

    return 0;   # success

}  # run_gcp()


sub run_cp {

    my ($src, $dest) = @_;

    my $run_pgm = "cp -fv '$src' '$dest'";

    open(FH, "$run_pgm |") or die "run_cp: Couldn't start cp: $!\n";
    while (<FH>) {
        print $_;
    }
    close FH or die $! ? "run_cp: Error closing cp pipe: $!\n"
                       : "run_cp: Exit status $? from closing cp\n";

    return 0;   # success

}  # run_cp()


#
# Copy files from $src to $dest
#
sub copy_files {

    my ($src, $dest) = @_;
    my $file = "";
    my ($filename, $dirname, $suffix) = ("", "", "");

    my $dt = get_date();    # YYYYMMDD

    log_msg "";  # print blank line to log
    print_log "copy_files: Copying files from $src/$dt to $dest/$dt";

    # Remove directory YYYYMMDD if it already exists
    if (-e "$dest/$dt")  {
        rmtree "$dest/$dt" or die "copy_files: Unable to rmtree $dest/$dt: $!\n";
    }

    mkdir "$dest/$dt" or die "copy_files: unable to mkdir for $dest/$dt\n";

    # Copy files in $src/YYYMMDD to $dest/YYYYMMDD directory.
    foreach my $file (<$src/$dt/*>) {
        ($filename, $dirname, $suffix) = fileparse($file);
        print_log "copy_files: Copying file \"$filename\"";

        if ( uc $ENV{"OS"} eq "WINDOWS_NT") {
            run_cp "$file", "$dest/$dt";
        } else {
            run_gcp "$file", "$dest/$dt";
        }
    }


    return 0    # success

}  # copy_files()



#
# Main Program
#
{

    if ( uc $ENV{"OS"} eq "WINDOWS_NT") {

        $HOME = "/c/Users/username";
        $LOGFILE = "$HOME/log/backup.log";
        $PROGNAME = basename $0;    # save script name

        $MYPASSPORT = "/e";
        $WINSYS2 = "/f";
        $WINSYS3 = "/g";
        $WINPROFILE = "/c/Users/username";

    } else {

        $HOME = $ENV{"HOME"};
        $LOGFILE = "$HOME/log/backup.log";
        $PROGNAME = basename $0;    # save script name

        $MYPASSPORT = "/media/my_passport";
        $WINSYS2 = "/media/WIN_SYS2";
        $WINSYS3 = "/media/WIN_SYS3";
        $WINPROFILE = "/media/Win10/Users/username";

    }

    $BACKUP = "$WINSYS3/Backup";
    # $BACKUP_MAIL = "$WINSYS3/Backup/evolution";

    $ITUNES = "$WINSYS2/iTunes";
    $ITUNES_BACKUP = "$WINSYS3/Music";

    $PICTURES = "$WINSYS3/Pictures";

    $THUNDERBIRD = "$WINSYS2/Thunderbird";
    # $THUNDERBIRD_BACKUP = "$MYPASSPORT/Backup";

    my $filename = "";
    my $tarfile = "";
    my $dt = get_date();
    my $flag = 0;

    # Check for at least one command-line argument
    if ( !@ARGV ) {
        # print "Usage: $PROGNAME [ home | usb ]\n";
        print "Usage: $PROGNAME [ sync | home | copy | music | all ]\n";
        exit 1;
    }

    my @args = qw/ sync home copy music all /;
    my $x = "";
    foreach $x (@args) {
        if ($ARGV[0] eq $x) { $flag = 1; }
    }

    if (! $flag) {
        print "Usage: $PROGNAME [ sync | home | copy | music | all ]\n";
        exit 1;
    }


    truncate_log($LOGFILE);


    if ( $ARGV[0] eq "sync" ) {

        # Sync iTunes folder to Backup folder.
        sync_folder "$ITUNES/", "$ITUNES_BACKUP";

        # Sync Thunderbird folder to Backup folder.
        # sync_folder "$THUNDERBIRD", "$BACKUP";

        # Sync folders in @DIRLIST to Backup folder.
        sync_home "$HOME", "$BACKUP";

    } elsif ( $ARGV[0] eq "home" ) {

        # Backup folders in @DIRLIST to tar.gz files
        backup_home "$BACKUP";

        # Backup "Music" and "Pictures" folders in SRC to tar.gz files.
        # backup_music_pics "$BACKUP"

    } elsif ( $ARGV[0] eq "music" ) {

        # Sync Music to $MYPASSPORT.
        sync_folder "$ITUNES/", "$MYPASSPORT/Music";

        # Sync Pictures to $MYPASSPORT.
        sync_folder "$PICTURES", "$MYPASSPORT";

    } elsif ( $ARGV[0] eq "copy" ) {

        # Copy *.tar.gz files to $MYPASSPORT.
        copy_files "$BACKUP", "$MYPASSPORT/Backup";

        # Copy evolution-backup-YYYYMMDD.tar.gz to $COPY/evolution
        # $tarfile = "evolution-backup-$dt.tar.gz";
        # if (-e "$BACKUP_MAIL/$tarfile") {
        #     run_cp "$BACKUP_MAIL/$tarfile", "$COPY/evolution/";
        # }

        # Copy Music.YYYYMMDD.tar.gz
        $filename="Music.$dt.tar.gz";
        if (-e "$BACKUP/$filename") {
            run_cp "$BACKUP/$filename", "$MYPASSPORT/Backup";
        }

        # Copy Pictures.YYYYMMDD.tar.gz
        $filename="Pictures.$dt.tar.gz";
        if (-e "$BACKUP/$filename") {
            run_cp "$BACKUP/$filename", "$MYPASSPORT/Backup";
        }

    } elsif ( $ARGV[0] eq "usb" ) {

        # Copy *.tar.gz files to flash drive..
        # copy_files "$BACKUP", "$MYPASSPORT/Backup";

    } elsif ( $ARGV[0] eq "all" ) {

        sync_folder "$ITUNES/", "$ITUNES_BACKUP";

        # sync_folder "$THUNDERBIRD", "$BACKUP";

        sync_home "$HOME", "$BACKUP";

        backup_home "$BACKUP";

        # Copy *.tar.gz files to $MYPASSPORT.
        copy_files "$BACKUP", "$MYPASSPORT/Backup";

        # Copy Music.YYYYMMDD.tar.gz
        $filename="Music.$dt.tar.gz";
        if (-e "$BACKUP/$filename") {
            run_cp "$BACKUP/$filename", "$MYPASSPORT/Backup";
        }

        # Copy Pictures.YYYYMMDD.tar.gz
        $filename="Pictures.$dt.tar.gz";
        if (-e "$BACKUP/$filename") {
            run_cp "$BACKUP/$filename", "$MYPASSPORT/Backup";
        }

    }


    # Let user know script has finished.
    log_msg "";  # print blank line to log
    print_log "Backup completed successfully.\n";

    exit 0;  # All is well

}