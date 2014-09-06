check_knuerr_cooltherm
======================

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

http://www.netways.de/en/de/produkte/icinga_and_nagios_plugins/knuerr/

### Requirements

* Perl libraries: `Net::SNMP`


### Usage

    check_knuerr_cooltherm -h

    check_knuerr_cooltherm --man

    check_knuerr_cooltherm -H <hostname> [<SNMP community>]

Options:

    -H  Hostname
    -C  Community string (default is "public")
    -h|--help
        Show help page
    --man
        Show manual
    -v--|verbose
        Be verbose
    -V  Show plugin name and version

    # ./check_kentix_multisensor -h HOST [-s COMMUNITY] [-t THRESHOLDS] [-w WARNING] [-c CRITICAL]


