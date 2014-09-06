#!/usr/bin/perl -w
# $Id$

=pod

=head1 COPYRIGHT

This software is Copyright (c) 2010 NETWAYS GmbH, Thomas Gelf
                               <support@netways.de>

(Except where explicitly superseded by other copyright notices)

=head1 LICENSE

This work is made available to you under the terms of Version 2 of
the GNU General Public License. A copy of that license should have
been provided with this software, but in any event can be snarfed
from http://www.fsf.org.

This work is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301 or visit their web page on the internet at
http://www.fsf.org.


CONTRIBUTION SUBMISSION POLICY:

(The following paragraph is not intended to limit the rights granted
to you to modify and distribute this software under the terms of
the GNU General Public License and is only of importance to you if
you choose to contribute your changes and enhancements to the
community by submitting them to NETWAYS GmbH.)

By intentionally submitting any modifications, corrections or
derivatives to this work, or any other work intended for use with
this Software, to NETWAYS GmbH, you confirm that
you are the copyright holder for those contributions and you grant
NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
royalty-free, perpetual, license to use, copy, create derivative
works based on those contributions, and sublicense and distribute
those contributions and any derivatives thereof.

Nagios and the Nagios logo are registered trademarks of Ethan Galstad.

=head1 NAME

check_knuerr_cooltherm

=head1 SYNOPSIS

check_knuerr_cooltherm -h

check_knuerr_cooltherm --man

check_knuerr_cooltherm -H <hostname> [<SNMP community>]

=head1 DESCRIPTION

This plugin monitors Knürr CoolTherm Server Cabinet sensors

MIB file is not required, OIDs are hardcoded.
Knürr Cooltherm Server Cabinet manual is to be found here:

  http://www.knuerr.com/web/zip-pdf/manuals/CoolTherm_Index_M.pdf

You can fetch the entire MIB file directly from the cabinet itself,
it's filename should be "KNUERR-COOLCON-MIB-Vx.mib".

There is no need to configure any threshold values, they are retrieved
automagically from your server cabinet. Supported sensors are temperature,
humidity, smoke, water, fan and humidity. Temperature and humidity values
are also available as trend data.

=head1 OPTIONS

=over

=item   B<-H>

Hostname

=item   B<-C>

Community string (default is "public")

=item   B<-h|--help>

Show help page

=item   B<--man>

Show manual

=item   B<-v--|verbose>

Be verbose

=item   B<-V>

Show plugin name and version

=cut

use Getopt::Long;
use Pod::Usage;
use File::Basename;
use Net::SNMP;

# predeclared subs
use subs qw/help fail fetchOids/;

# predeclared vars
use vars qw (
  $PROGNAME
  $VERSION

  %states
  %state_names
  %performance

  @info
  @perflist

  $opt_host
  $opt_help
  $opt_man
  $opt_verbose
  $opt_version
);

# Main values
$PROGNAME = basename($0);
$VERSION  = '1.0';

# Nagios exit states
%states = (
	'OK'       => 0,
	'WARNING'  => 1,
	'CRITICAL' => 2,
	'UNKNOWN'  => 3
);

# Nagios state names
%state_names = (
	0 => 'OK',
	1 => 'WARNING',
	2 => 'CRITICAL',
	3 => 'UNKNOWN'
);

# SNMP
my $opt_community = "public";
my $snmp_version  = "2c";
my $global_state = 'OK';

# Retrieve commandline options
Getopt::Long::Configure('bundling');
GetOptions(
	'h|help'    => \$opt_help,
	'man'       => \$opt_man,
	'H=s'       => \$opt_host,
	'C=s',      => \$opt_community,
	'v|verbose' => \$opt_verbose,
	'V'		    => \$opt_version
) || help( 1, 'Please check your options!' );

# Any help needed?
help( 1) if $opt_help;
help(99) if $opt_man;
help(-1) if $opt_version;
help(1, 'Not enough options specified!') unless ($opt_host);

### OID definitions ###
my $vendor  = '.1.3.6.1.4.1.2769'; # Enterprise OID for Knürr CoolTherm
my $baseOid = $vendor . '.2.1';    # All required values are to be found here

# Prepare SNMP Session
($session, $error) = Net::SNMP->session(
	-hostname  => $opt_host,
	-community => $opt_community,
	-port      => 161,
	-version   => $snmp_version,
);
fail('UNKNOWN', $error) unless defined($session);

checkTemperature();
checkHumidity();
checkStati();
foreach (keys %performance) {
	push @perflist, $_ . '=' . $performance{$_};
}
printf('%s %s|%s', $global_state, join(', ', @info), join(' ', @perflist));
exit $states{$global_state};

###
# Fetch given OIDs, return a hash
#
# Use one SNMP get request for not more than 10 OIDs
###
sub fetchOids {
	my %result;
	my @oids = @{$_[0]};
	my $r = $session->get_request(@oids);
	if (!defined($r)) {
		fail('CRITICAL', "Failed to query device $opt_host");
	};
    foreach (keys %{$r}) {
       $result{$_} = $r->{$_};
    }
	return %result;
}

sub raiseGlobalState {
	my @states = @_;
	foreach my $state (@states) {
		# Pay attention: UNKNOWN > CRITICAL
		if ($states{$state} > $states{$global_state}) {
			$global_state = $state;
		}
	}
}

sub checkTemperature {
	# returnAir, backside temperature
	my $current1  = $baseOid . '.1.1.3.0';
	my $warning1  = $baseOid . '.1.1.5.0';
	my $critical1 = $baseOid . '.1.1.6.0';
	# supplyAir, frontside temperature
	my $current2  = $baseOid . '.1.2.3.0';
	my $warning2  = $baseOid . '.1.2.5.0';
	my $critical2 = $baseOid . '.1.2.6.0';
	my @oids = (
		$current1, $warning1, $critical1,
		$current2, $warning2, $critical2
	);

	my %result = fetchOids(\@oids);

	my $state1 = 'OK';
    $state1 = 'WARNING'  if $result{$current1} / 10 >= $result{$warning1};
    $state1 = 'CRITICAL' if $result{$current1} / 10 >= $result{$critical1};
	my $state2 = 'OK';
    $state2 = 'WARNING'  if $result{$current2} / 10 >= $result{$warning2};
    $state2 = 'CRITICAL' if $result{$current2} / 10 >= $result{$critical2};
	raiseGlobalState($state1, $state2);

	$performance{'returnAirTemp'} = sprintf(
		"%.1f;%.1f;%.1f;0;80",
		$result{$current1} / 10,
		$result{$warning1},
		$result{$critical1}
	);
	$performance{'supplyAirTemp'} = sprintf(
		"%.1f;%.1f;%.1f;0;80",
		$result{$current1} / 10,
		$result{$warning1},
		$result{$critical1}
	);

	push @info, sprintf(
		'ReturnAirTemp %s: %.1f (:%.1f/:%.1f)',
		$state1,
		$result{$current1} / 10,
		$result{$warning1},
		$result{$critical1}
	);
	push @info, sprintf(
		'SupplyAirTemp %s: %.1f (:%.1f/:%.1f)',
		$state2,
		$result{$current2} / 10,
		$result{$warning2},
		$result{$critical2}
	);
}

sub checkHumidity {
	my $current  = $baseOid . '.1.7.2.0';
	my $lowCrit  = $baseOid . '.1.7.3.0';
	my $highCrit = $baseOid . '.1.7.4.0';
	my @oids    = ($current, $lowCrit, $highCrit);
	my %result  = fetchOids(\@oids);
	my $state = 'OK';
	my $lowWarn  = $result{$lowCrit};
	my $highWarn = $result{$highCrit};
	if ($result{$highCrit} - $result{$lowCrit} > 40) {
		if ($result{$current} / 10 <= $result{$lowCrit} + 15
		    || $result{$current} / 10 >= $result{$highCrit} - 15) {
			$state = 'WARNING';
		}
		$lowWarn  = $result{$lowCrit}  + 15;
		$highWarn = $result{$highCrit} - 15;
	}
	if ($result{$current} / 10 <= $result{$lowCrit}
        || $result{$current} / 10 >= $result{$highCrit}) {
		$state = 'CRITICAL';
	}

	raiseGlobalState($state);
	$performance{'humidity'} = sprintf(
		"%.1f%%;%.1f:%.1f;%.1f:%.1f;0;100",
		$result{$current} / 10,
		$lowWarn,
		$highWarn,
		$result{$lowCrit},
		$result{$highCrit}
	);
	push @info, sprintf(
		'Humidity %s: %.1f (%.1f:%.1f/%.1f:%.1f)',
		$state,
		$result{$current} / 10,
		$lowWarn,
		$highWarn,
		$result{$lowCrit},
		$result{$highCrit}
	);
}

sub checkStati {
    my $fan1   = $baseOid . '.2.4.1.0';
    my $fan2   = $baseOid . '.2.4.2.0';
    my $fan3   = $baseOid . '.2.4.3.0';
	my $water  = $baseOid . '.2.4.5.0';
	my $smoke  = $baseOid . '.2.4.6.0';
	my $mainsA = $baseOid . '.2.4.7.0';
	my $mainsB = $baseOid . '.2.4.8.0';
	my @oids    = (
		$fan1, $fan2, $fan3,
		$water, $smoke,
		$mainsA, $mainsB
	);
	my %st = (
		0 => 'OK',
		1 => 'KO'
	);
	my %result  = fetchOids(\@oids);
	my $stateFan = 'OK';
	my $failedFan = $result{$fan1} + $result{$fan2} + $result{$fan3};
	$stateFan = 'WARNING' if $failedFan > 0;
	$stateFan = 'CRITICAL' if $failedFan > 1;
	my $stateWater = $result{$water} == 0 ? 'OK' : 'CRITICAL';
	my $stateSmoke = $result{$smoke} == 0 ? 'OK' : 'CRITICAL';
	my $statePower = $result{$mainsA} + $result{$mainsB} == 0 ? 'OK' : 'CRITICAL';
	raiseGlobalState($stateFan, $stateWater, $stateSmoke, $statePower);
	push @info, sprintf(
		'Fan1: %s, Fan2: %s, Fan3: %s, Water: %s, Smoke: %s, PowerSupplyA: %s, PowerSupplyB: %s',
        $st{$result{$fan1}},
        $st{$result{$fan2}},
        $st{$result{$fan3}},
        $st{$result{$water}},
        $st{$result{$smoke}},
        $st{$result{$mainsA}},
        $st{$result{$mainsB}}
	)
}

# Print error message and terminate program with given status code
sub fail {
	my ($state, $msg) = @_;
	print $state_names{ $states{$state} } . ": $msg";
	exit $states{$state};
}


# help($level, $msg);
# prints some message and the POD DOC
sub help {
	my ($level, $msg) = @_;
	$level = 0 unless ($level);
	if ($level == -1) {
		print "$PROGNAME - Version: $VERSION\n";
		exit $states{UNKNOWN};
	}
	pod2usage({
		-message => $msg,
		-verbose => $level
	});
	exit $states{'UNKNOWN'};
}

1;

