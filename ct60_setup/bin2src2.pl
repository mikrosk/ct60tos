#!/usr/bin/perl
#	Generate source for ARAnyM integration in TOS patches

$file = @ARGV[0];
$filesize = -s $file;

$start_address = 0x07ab00+0x150;

if ( ! defined(open(FILE, $file)) ) {
	warn "Couldn't open $file: $!\n";
	exit;
}

binmode(FILE);

if (read(FILE, $buf, $filesize) != $filesize) {
	warn "Failed reading $filesize bytes\n";
	exit;
}

if ($start_address+$filesize>0x80000-2) {
	warn "File too big\n";
	exit;
}

close(FILE);

print "/* Generated by bin2src2.pl from $file */\n";
printf "/* filesize 0x%08x */\n\n", $filesize;

push @array, unpack "C*", $buf;

$index = 0;
print "\ti = 0x07b1b0;\n";
for ($count = 0; $count<$filesize; $count++) {
	printf "\tROMBaseHost[i++] = 0x%08x;\n", @array[$count];
}

exit;