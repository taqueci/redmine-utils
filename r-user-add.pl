=head1 NAME

r-user-add.pl - create a new Redmine user

=head1 SYNOPSIS

    r-user-add.pl [OPTION] ... LOGIN FIRST_NAME LAST_NAME MAIL

=head1 DESCRIPTION

This script creates a new Redmine user.

=head1 OPTIONS

=over 4

=item --url=URL

Access to URL.

=item --key=KEY

Use KEY as Redmine administrator's API access key.

=item --redmine-user=USER

Use USER as Redmine administrator's login name.
This option is ignored if option --key is specified.

=item --redmine-password=PASSWD

Use PASSWD as Redmine administrator's password.
This option is ignored if option --key is specified.

=item -p PASSWD, --password=PASSWD

Set a user password to PASSWD.

=item -a AUTH_SRC_ID, --auth-source-id=AUTH_SRC_ID

Set an authentication source to AUTH_SRC_ID.

=item -m NOTIF, --mail-notification=NOTIF

Set mail notification to NOTIF. (e.g. 'only_my_events', 'none', ...)

=item -c, --must-change-passwd

Force a user to change the password.

=item -l FILE, --log=FILE

Write log to FILE.

=item --verbose

Print verbosely.

=item --help

Print this help.

=back

=head1 EXAMPLE

    r-user-add.pl --rul=http://www.gnr.com/redmine \
        --key=0123456789abcdef0123456789abcdef01234567 \
        --auth-source-id=3 --mail-notification=none \
        a.rose Axl Rose a.rose@gnr.com

=head1 AUTHOR

Takeshi Nakamura <taqueci.n@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2015 Takeshi Nakamura. All Rights Reserved.

=cut

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev gnu_compat);
use HTTP::Request;
use LWP::UserAgent;
use Pod::Usage;
use URI::URL;

my $PROGRAM = basename $0;

my $p_message_prefix = "";
my $p_log_file;
my $p_is_verbose = 0;

p_set_message_prefix("$PROGRAM: ");

my %opt = (url => 'http://localhost', encoding => 'utf-8');
GetOptions(\%opt, 'url=s', 'key=s', 'redmine-user=s', 'redmine-password=s',
		   'password|p=s', 'auth-source-id|a=i', 'mail-notification|m=s',
		   'must-change-passwd|c', 'encoding|e=s',
		   'log|l=s', 'verbose', 'help') or exit 1;

p_set_log($opt{log}) if defined $opt{log};
p_set_verbose(1) if $opt{verbose};

pod2usage(-exitval => 0, -verbose => 2, -noperldoc => 1) if $opt{help};

@ARGV == 4 or p_error_exit(1, 'Invalid arguments');

my ($login, $fname, $lname, $mail) = @ARGV;

my $xml = _user_xml($login, $fname, $lname, $mail, $opt{password},
					$opt{'auth-source_id'}, $opt{'mail-notification'},
					$opt{'must-change-passwd'}, $opt{encoding});

p_verbose("Adding user $login");
_add_user($xml, $opt{url}, $opt{key},
		  $opt{'redmine-user'}, $opt{'redmine-passowrd'}) or exit 1;

p_verbose("Completed!\n");

exit 0;


sub p_message {
	my @msg = ($p_message_prefix, @_);

	print STDERR @msg, "\n";
	p_log(@msg);
}

sub p_warning {
	my @msg = ("*** WARNING ***: ", $p_message_prefix, @_);

	print STDERR @msg, "\n";
	p_log(@msg);
}

sub p_error {
	my @msg = ("*** ERROR ***: ", $p_message_prefix, @_);

	print STDERR @msg, "\n";
	p_log(@msg);
}

sub p_verbose {
	my @msg = @_;

	print STDERR @msg, "\n" if $p_is_verbose;
	p_log(@msg);
}

sub p_log {
	my @msg = @_;

	return unless defined $p_log_file;

	open my $fh, '>>', $p_log_file or die "$p_log_file: $!\n";
	print $fh @msg, "\n";
	close $fh;
}

sub p_set_message_prefix {
	my $prefix = shift;

	defined $prefix or croak 'Invalid argument';

	$p_message_prefix = $prefix;
}

sub p_set_log {
	my $file = shift;

	defined $file or croak 'Invalid argument';

	$p_log_file = $file;
}

sub p_set_verbose {
	$p_is_verbose = (!defined($_[0]) || ($_[0] != 0));
}

sub p_exit {
	my ($val, @msg) = @_;

	print STDERR @msg, "\n";
	p_log(@msg);

	exit $val;
}

sub p_error_exit {
	my ($val, @msg) = @_;

	p_error(@msg);

	exit $val;
}

sub _user_xml {
	my ($login, $fname, $lname, $mail, $passwd,
		$auth_src_id, $mail_notif, $chg_passwd, $encoding) = @_;
	my @x;

	push @x,
	"<?xml version=\"1.0\" encoding=\"utf-8\" ?>",
	"<user>",
	"  <login>$login</login>",
	"  <firstname>" . decode($encoding, $fname) . "</firstname>",
	"  <lastname>" . decode($encoding, $lname) . "</lastname>",
	"  <mail>$mail</mail>";

	push @x,
	"  <auth_source_id>$auth_src_id</auth_source_id>" if $auth_src_id;

	push @x,
	"  <mail_notification>$mail_notif</mail_notification>" if $mail_notif;

	push @x,
	"  <must_change_passwd>true</must_change_passwd>" if $chg_passwd;

	push @x,
	"</user>";

	my $xml = join("\n", @x) . "\n";

	p_log(encode($encoding, $xml));

	return $xml;
}

sub _add_user {
	my ($xml, $url, $key, $user, $passwd) = @_;

	# Remove trailing slash.
	$url =~ s/\/$//;

	my $req = HTTP::Request->new(POST => "$url/users.xml");
	$req->content_type('text/xml');
	$req->content(encode('utf-8', $xml));

	if (defined $key) {
		$req->header('X-Redmine-API-Key' => $key);
	}
	else {
		$req->authorization_basic($user // _read_stdin('User: '),
								  $passwd // _read_stdin('Password: '));
	}

	p_log("Acessing to $url");

	my $agent = LWP::UserAgent->new();
	my $resp = $agent->request($req);

	unless ($resp->is_success) {
		p_error($resp->status_line);
		return 0;
	}

	return 1;
}

sub _read_stdin {
	print shift;

	my $input = <STDIN>;
	chomp $input;

	return $input;
}
