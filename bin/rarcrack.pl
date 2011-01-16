#!/usr/bin/perl
#
use strict;
use warnings;
use IO::Handle;
use List::Util ();

my $base_alph = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.:/ ';

my $rar_archive;
my $threads;
my $unrar_prog;
my $pass_start;

my @alph = split //, $base_alph;

sub help
{
	print <<EOF;
	$0 [options] <rar_archive>

Options:
	--alph-add CHARS	Add chars to alphabet.
	--alph-rm CHARS		Remove chars from alphabet.
	--alph-set CHARS	Set the alphabet.
	--start-pass PASS	Start at this password.
	--threads NUM		Number of threads. Set to $threads.
EOF
}

sub parse_argv
{
	my $die = 0;
	while ( my $opt = shift @ARGV ) {
		if ( $opt eq "--alph-add" ) {
			unless ( @ARGV ) {
				warn "--alph-add requires an argument\n";
				$die++;
			}
			alph_add( shift @ARGV );
		} elsif ( $opt eq "--alph-rm" ) {
			unless ( @ARGV ) {
				warn "--alph-rm requires an argument\n";
				$die++;
			}
			alph_rm( shift @ARGV );
		} elsif ( $opt eq "--alph-set" ) {
			unless ( @ARGV ) {
				warn "--alph-set requires an argument\n";
				$die++;
			}
			alph_set( shift @ARGV );
		} elsif ( $opt eq "--alph-clear" ) {
			alph_set( "" );
		} elsif ( $opt eq "--threads" ) {
			unless ( @ARGV ) {
				warn "--threads requires an argument\n";
				$die++;
			}
			$threads = shift @ARGV;
			unless ( $threads =~ /^[1-9]\d*$/ ) {
				warn "--threads requires a numeric argument (>= 1)\n";
				$die++;
			}
			$threads |= 0;
		} elsif ( $opt eq "--start-pass" ) {
			unless ( @ARGV ) {
				warn "--start-pass requires an argument\n";
				$die++;
			}
			$pass_start = shift @ARGV;
		} elsif ( $opt =~ /^-?-h(elp)?$/ ) {
			help();
			exit;
		} elsif ( defined $rar_archive ) {
			warn "'$opt' is not an option and archive is already specified\n";
			$die++;
		} else {
			if ( -r $opt ) {
				$rar_archive = $opt;
			} else {
				warn "Cannot read file '$opt'\n";
				$die++;
			}
		}
	}
	if ( not $unrar_prog or not -x $unrar_prog ) {
		warn "Cannot find (un)rar application\n";
		$die++;
	}
	if ( not defined $rar_archive ) {
		warn "rar file is missing\n";
		$die++;
	}
	die "Exiting because of errors\n" if $die;
}

sub init_vars
{
	$threads = `/usr/bin/getconf _NPROCESSORS_ONLN 2>/dev/null`;
	$threads = 1 unless $threads;
	$threads |= 0; # make it an integer
	
	$unrar_prog = find_prog( qw(unrar rar) );
}

sub alph_add
{
	my $add = shift;
	foreach my $chr ( split //, $add ) {
		push @alph, $chr
			unless defined List::Util::first { $_ eq $chr } @alph;
	}
	
}

sub alph_rm
{
	my $rm = shift;
	my @rm = split //, $rm;
	my @newalph;
	foreach my $chr ( @alph ) {
		push @newalph, $chr
			unless defined List::Util::first { $_ eq $chr } @rm;
	}
	@alph = @newalph;
}

sub alph_set
{
	my $set = shift;
	@alph = split //, $set;
}


my %alph_chr2num;
my $alph_charset;
sub alph_prepare
{
	print "Using alphabet:\n", (join "", @alph), "\n";
	foreach my $i ( 0..$#alph ) {
		$alph_chr2num{ $alph[ $i ] } = $i;
	}
	$alph_charset = join "", @alph;
}

sub find_prog
{
	local $_;
	while ( my $prog = shift @_ ) {
		foreach my $dir ( split /:/, $ENV{PATH} ) {
			$_ = $dir . "/" . $prog;
			return $_ if -x $_;
		}
	}
}

sub find_smallfile
{
	my $file = shift;

	open my $rarlist, "-|", $unrar_prog, "v", $file;
	while ( <$rarlist> ) {
		last if /-{79}/;
	}

	my $smallfile_name;
	my $smallfile_size;
	while ( <$rarlist> ) {
		chomp;
		last if /-{79}/;
		next unless /^\*(.*)$/;

		my $name = $1;
		$_ = <$rarlist>;
		redo unless /\s+(\d+)\s+\d+\s+\d+%/;
		my $size = $1 | 0;

		if ( not defined $smallfile_size or $smallfile_size > $size ) {
			$smallfile_size = $size;
			$smallfile_name = $name;
		}

	}

	return $smallfile_name;
}

init_vars();
parse_argv();
alph_prepare();

my $small_file = find_smallfile( $rar_archive );
unless ( defined $small_file ) {
	die "Cannot find an encrypted file in $rar_archive\n";
}
print "Smallest file: '$small_file'\n";

my $rar_status = $rar_archive . ".crackstatus";

my @pass_current = ();
my $pass_lastchar = -1;
my $pass_last; # last tried password
my $pass_root = ''; # password without last character
my $tries = 0;

sub pass_updateroot
{
	my $last = 1;
	$pass_lastchar = 0;
	foreach ( reverse @pass_current ) {
		$_++;
		if ( $_ < @alph ) {
			$last = 0;
			last;
		} else {
			$_ = 0;
		}
	}
	if ( $last ) {
		push @pass_current, 0;
	}
	$pass_root = join "", map { $alph[ $_ ] } @pass_current;
}

sub getpass
{
	$tries++;
	$pass_lastchar++;
	if ( $pass_lastchar >= @alph ) {
		pass_updateroot();
	}

	return $pass_last = $pass_root . $alph[ $pass_lastchar ]; 
}

sub set_startpass
{
	my $pass = shift;
	@pass_current = ();
	foreach my $chr ( split //, $pass ) {
		unless ( exists $alph_chr2num{ $chr } ) {
			die "Start password: $pass has a non-alphabet char: $chr\n";
		}
		push @pass_current, $alph_chr2num{ $chr };
	}
	$pass_lastchar = (pop @pass_current) - 1;
	$pass_root = join "", map { $alph[ $_ ] } @pass_current;
}

if ( defined $pass_start ) {
	set_startpass( $pass_start );
}

sub readstr
{
	my $fh = shift;

	my $len;
	my $string;

	return undef unless 1 == read $fh, $len, 1;
	$len = ord $len;

	return undef unless $len == read $fh, $string, $len;

	return $string;
}

if ( -r $rar_status ) {
	open my $f_in, "<", $rar_status;

	my $start = readstr( $f_in );
	my $alph = readstr( $f_in );

	close $f_in;

	if ( defined $start and defined $alph ) {
		warn "using data from status file\n";

		alph_set( $alph );
		alph_prepare();
	
		set_startpass( $start );
	}
}

my $children = 0;
my %by_pid;
sub run_unrar
{
	my $pass = shift;

	my $pid = fork();

	return undef unless defined $pid;
	if ( $pid ) {
		$children++;
		$by_pid{ $pid } = $pass;
		return;
	}

	exec { $unrar_prog } $unrar_prog, "t", "-inul", "-p$pass", $rar_archive, $small_file;
}

my $pass_lastbad;
sub waitchld
{
	my $pid = wait;
	$children--;
	my $ret = $?;

	my $pass = $by_pid{ $pid };
	delete $by_pid{ $pid };
	if ( $ret == 3 << 8 ) {
		$pass_lastbad = $pass;
		run_unrar( getpass() );
	} elsif ( $ret == 0 ) {
		$pass_lastbad = $pass;
		write_status();
		print "\nFound pass: $pass\n";
		exit 0;
	} else {
		warn "unrecognized exit code: $ret, rerunning $pass\n";
		run_unrar( $pass );
	}
}

sub write_status
{
	open my $f_out, ">", $rar_status . ".new";
	$f_out->print( chr length $pass_lastbad, $pass_lastbad, chr length $alph_charset, $alph_charset );
	close $f_out;
	rename $rar_status . ".new", $rar_status;
}

while ( $children < $threads ) {
	run_unrar( getpass() );
}

my $nexttime = 0;
my $lasttries = 0;
while ( 1 ) {
	waitchld();
	if ( time > $nexttime ) {
		$nexttime = time;
		my $speed = $tries - $lasttries;
		$lasttries = $tries;
		print "\rLast password: $pass_last ($speed / sec)";
		STDOUT->flush();
		if ( $children < $threads ) {
			warn "Not enough children: $children\n";
			run_unrar( getpass() );
		}

		write_status();
	}
}
