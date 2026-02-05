#!/usr/bin/perl
# Extract valid nicks from IRCCloud logs for pisg
# Usage: perl extract_nicks.pl logfile.txt > nicks.cfg

use strict;
use warnings;

my %nicks;

while (<>) {
    # Joins: → nick joined (host)
    if (/^\[.*\] → (\S+) joined/) {
        $nicks{lc($1)} = $1;
    }
    # Nick changes: — oldnick is now known as newnick
    elsif (/^\[.*\] — (\S+) is now known as (\S+)/) {
        $nicks{lc($1)} = $1;
        $nicks{lc($2)} = $2;
    }
    # Speakers: <nick> message (fallback for nicks without join events)
    elsif (/^\[.*\] <([^>]+)>/) {
        my $nick = $1;
        # Skip if it looks like a bot relay format
        next if $nick =~ /^(discordsync|BotSaget|bloomberg_terminal)/i;
        $nicks{lc($nick)} = $nick unless exists $nicks{lc($nick)};
    }
}

# Output as pisg user entries
print "# Auto-generated valid nicks list\n";
print "# Generated from: @ARGV\n\n";

for my $nick (sort { lc($a) cmp lc($b) } values %nicks) {
    # Skip obviously invalid nicks (too short, common words)
    next if length($nick) < 2;
    next if $nick =~ /^(the|is|it|in|on|to|of|for|and|but|or|if|so|as|at|by|i|a)$/i;
    next if $nick =~ /^(Channel|Socket|Joined)$/;
    print "<user nick=\"$nick\">\n";
}
