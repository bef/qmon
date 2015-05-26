qmon - Q Monitoring App
=======================

![alt tag](https://raw.githubusercontent.com/bef/qmon/master/logo/qmon-logo-269-flat.png)

About
-----
qmon is a simple monitoring application suitable for a small number of hosts and services. It aims to be a quick and secure alternative to nagios with focus on simplicity.

Features:

* Simple INI-style configuration file
* Powerful macro processor for similar configuration entries
* Nagios-compatibility: Check scripts from the nagios or icinga package can be used with qmon. Multiline output is not supported though.
* Notification by XMPP
* CGI-based web frontend


Installation
------------
Required packages:

* Tcl 8.6 or 8.5 (8.6 is preferred)
* Tcllib 1.13
* sqlite-tcl
* xmpppy 0.4.1 or 0.5 (optional: for notify\_via\_xmpp plugin)
* nagios or icinga plugins (optional)

Example package installation with Debian/Ubuntu:

	# apt-get install tcl8.6 tcllib libsqlite3-tcl tcl-tls
	# apt-get install nagios-plugins-standard nagios-plugins-contrib

	# apt-get install python-xmpp
	(or) # pip install xmpppy --pre

Example package installation with Activestate Tcl 8.6:

	# ln -s /opt/ActiveTcl-8.6/bin/tclsh8.6 /usr/local/bin
	# teacup update --only newer ## (!! not 'teacup update'. bad idea.)
	# teacup install inifile
	# teacup install ncgi
	# teacup install html
	# teacup install term::ansi::code::ctrl

Create dedicated qmon user and group:

	# groupadd qmon
	# useradd -g qmon -d /var/run/qmon qmon
	# mkdir -p /var/run/qmon
	# chown qmon:qmon /var/run/qmon
	
In /opt clone qmon from github:

	# cd /opt
	# git clone https://github.com/bef/qmon.git

Configure qmon for use with Tcl 8.5, if Tcl 8.6 is not available: Edit 'qmon' to invoke tclsh8.5:

	TCLSH=tclsh8.5

Create initial configuration file, e.g.

	[global]
	plugin_path=/opt/qmon/plugins /usr/lib/nagios/plugins
	default_interval=3600

Then create sqlite DB:

	# mkdir db
	# ./qmon update
	# chown -R root:qmon db
	# chmod 2775 db
	# chmod 664 db/qmon.db

Configure qmon (see below), then

	# ./qmon update

Secure sensitive configuration files, e.g.

	# chown root:qmon /opt/qmon/etc/*.ini
	# chmod 640 /opt/qmon/etc/*.ini

Go live: Edit crontab:

	# crontab -u qmon -e

	PATH=/usr/local/bin:/usr/bin:/bin 
	0-59/5 * * * * /opt/qmon/qmon check

Install web-frontend, e.g. with boa add two lines to boa.conf:

	ScriptAlias /cgi-bin/qmon /opt/qmon/cgi-bin
	Alias /qmon /opt/qmon/htdocs

OR with apache2, copy apache.conf.sample to apache.conf and add this line to a vhost configuration:

	Include /opt/qmon/etc/apache.conf



Configuration
-------------

### qmon.ini ###

See 'etc/qmon.ini.sample' for a quick start.

Format description:

* qmon.ini consists of INI-style sections (e.g. \[test\]) with key/value pairs (a=b).
* \[global\] is reserved for global settings. Other sections are either host descriptions or check descriptions. 
* ';' starts a one-line comment.
* type=check can be omitted.
* The value of 'cmd' does variable substitution, specifically $cfg(...) where ... is 'section.key', e.g. $cfg(ex.hostname)
* Every _host_ implicitly sets 'desc' and 'type=host'
* Unless explicitly changed every _check_ sets 'cmd', 'desc', 'host=unknown', 'type=check', 'interval=$cfg(global.default\_interval)', 'enabled=1'

Example:

	[global]
	plugin_path=/opt/qmon/plugins /usr/lib/nagios/plugins
	default_interval=3600
	;notify_cmd=echo -e "$name is now $status2 (was $status)" | ${::qmondir}/plugins/notify_via_xmpp me@jabber.example.com

	[tohu]
	type=host

	[ex]
	type=host
	hostname=example.com
	ip_pub=...
	ip_priv=...
	desc=example.com

	[ex_ssh]
	type=check
	host=ex
	desc=SSH
	cmd=check_ssh -H $cfg(na.hostname) -4
	; enabled=0

The ini-parser comes with a simple, yet powerful macro processor. This is useful for reusing snippets in a way functions or procedures work with programming languages. Example:

	#template X %COLOR% %ANIMAL1% %ANIMAL2%
	the quick %COLOR% %ANIMAL1% jumps over the lazy %ANIMAL2%
	#end template
	#use X brow fox dog
	
This would result in

	the quick brow fox jumps over the lazy dog

Template arguments can be any word with or without special characters, e.g. %COLOR%, $color, C, but the %%-syntax avoids accidental substitutions.

Multi-word arguments can be enclosed by "" or {}, e.g. "-h example.com".

Templates can be nested, however mind multi-word arguments:

	#template A %1% %2%
	#use B {%1%} {%2%}
	#end template

	#template B %1% %2%
	arg1=%1%
	arg2=%2%
	#end template

	[B]
	#use B {1 2 -e "foo"} 3 4
	[A]
	#use A {1 2 -e "foo"} 3 4

Output:

	[B]
	arg1=1 2 -e "foo"
	arg2=3
	[A]
	arg1=1 2 -e "foo"
	arg2=3

The third argument (here '4') is silently discarded.


### qmon ###

The launch script 'qmon' may be edited to reflect your installation preferences, such as TCLSH, directories, filenames, e.g.:

	QMON=/usr/lib/qmon
	TCLSH=/some/obscure/tclsh8.6
	EXTRA_ARGS="-ini /etc/qmon/qmon.ini -db /var/lib/qmon/qmon.db -lib /usr/share/qmon/lib"

Usage
-----

try 'qmon -h'


Plugins
=======

notify\_via\_xmpp
-----------------
This plugin sends arbitrary messages via XMPP. This is probably most useful with the global configuration

	notify_cmd=echo -e "$name is now $status2 (was $status)" | ${::qmondir}/plugins/notify_via_xmpp user1@jabber.example.com user2@jabber.example.com

Account credentials are in etc/notify\_via\_xmpp.ini:

	[jidparams]
	jid=qmon@jabber.example.com/qmon
	password=123456

The notification logic is kept simple on purpose. Every state change from a check results in the execution of notify\_cmd. Further logic such as notification groups or notify via xmpp and email have or only during work hours ... have to be implemented separately within notify\_cmd.


check\_netstat
--------------
This plugin parses the output of 'netstat -lntu', which shows the listening TCP and UDP ports on linux hosts. A list of 'protocol,IP:port' triplets is then matched against the configuration in the order as configured, but usually 'ok', 'warning', 'critical'.

String pattern may contain wildcards '?', '*' and '\[chars\]' for 1, >=0 or specific charecters.

Example: 'tcp4,127.0.0.1:80' would be matched by any of the following patterns:

	tcp4,127.0.0.1:80
	tcp*,*:80
	*,127.0.0.1:*

Complete example (keys must be unique but have no meaning):

	[global]
	order=ok,warning,critical

	[ok]
	http=tcp*,*:80
	https=tcp*,*:443
	ignore=*,192.168.250:*
	; localhost=*,127.0.0.1:*
	samba=*:139

	[warning]
	localhost=*,127.0.0.1:*
	localhost6=*,::1:*

	[critical]
	catchall=*

