package Pisg::Parser::Format::irccloud;

# Hybrid IRC log format parser for pisg
# Handles both IRCCloud export format (Unicode arrows) and ZNC/energymech format (*** prefix)
# This allows mixing historical IRCCloud logs with live ZNC logs

use strict;
$^W = 1;

use Pisg::Common;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        # [YYYY-MM-DD HH:MM:SS] <nick> message
        normalline => '^\[[^\]]*(\d{2}):\d+:\d+\] <([^>]+)> (.*)$',
        # [YYYY-MM-DD HH:MM:SS] * nick action
        actionline => '^\[[^\]]*(\d{2}):\d+:\d+\] \* (\S+) (.*)$',
        # Match joins, quits, parts, nick changes, kicks, topics
        thirdline  => '^\[[^\]]*(\d{2}):(\d+):\d+\] (.+)$'
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

        # Bridge nick handling (for Discord sync bots, etc.)
        my @bridge_nicks = split /\s+/, ($self->{cfg}->{bridgenicks} // '');

        if (@bridge_nicks && grep { $hash{nick} =~ /^\Q$_\E/ } @bridge_nicks) {
            my $clean_saying = $hash{saying};
            $clean_saying =~ s/\x03\d{0,2}(?:,\d{1,2})?//g;
            $clean_saying =~ s/[\x02\x0f\x16\x1d\x1f]//g;

            if ($clean_saying =~ /^<@?([^>]+)>\s*(.*)$/) {
                my ($real_nick, $real_msg) = ($1, $2);

                $real_nick =~ s/\p{Cf}//g;
                $real_nick =~ s/^\s+|\s+$//g;
                $real_nick =~ s/\s+/_/g;
                $real_nick =~ s/[^a-zA-Z0-9_\-\[\]\\\^\{\}`|]//g;

                if ($real_nick && length($real_nick) > 0) {
                    $hash{nick}   = $real_nick;
                    $hash{saying} = $real_msg;
                    add_valid_nick($real_nick);
                } else {
                    return;
                }
            } else {
                return;
            }
        }

        # Register speaker as valid nick
        add_valid_nick($hash{nick});

        return \%hash;
    } else {
        return;
    }
}

sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

        # Skip kick lines - they're handled in thirdline
        return if $hash{saying} =~ /^was kicked by/;

        # Skip topic lines - they're handled in thirdline
        return if $hash{saying} =~ /^set the topic to/;

        # Skip mode lines - they're handled in thirdline
        return if $hash{saying} =~ /^set [+-][a-zA-Z]/;

        # Skip IRCCloud system messages that look like actions
        return if $hash{nick} eq 'Channel' && $hash{saying} =~ /^(mode is|timestamp is)/;
        return if $hash{nick} eq 'Socket' && $hash{saying} =~ /^closed/;
        return if $hash{nick} eq 'Joined' && $hash{saying} =~ /^channel/;

        return \%hash;
    } else {
        return;
    }
}

sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min}  = $2;
        my $rest = $3;

        # Join: → nick joined (host)
        if ($rest =~ /^→ (\S+) joined/) {
            $hash{nick} = $1;
            $hash{newjoin} = $1;
            add_valid_nick($1);
            return \%hash;
        }

        # Quit: ⇐ nick quit (host): reason
        if ($rest =~ /^⇐ (\S+) quit/) {
            $hash{nick} = $1;
            # pisg doesn't track quits specifically, but we return the nick
            return \%hash;
        }

        # Part: ← nick left (host): reason
        if ($rest =~ /^← (\S+) left/) {
            $hash{nick} = $1;
            return \%hash;
        }

        # Nick change: — oldnick is now known as newnick
        if ($rest =~ /^— (\S+) is now known as (\S+)/) {
            $hash{nick} = $1;
            $hash{newnick} = $2;
            add_valid_nick($1);
            add_valid_nick($2);
            return \%hash;
        }

        # Kick: * nick was kicked by kicker (reason)
        if ($rest =~ /^\* (\S+) was kicked by (\S+) \((.+)\)$/) {
            $hash{nick} = $1;
            $hash{kicker} = $2;
            $hash{kicktext} = $3;
            return \%hash;
        }

        # Topic: * nick set the topic to [new topic] or * nick set the topic to: new topic
        if ($rest =~ /^\* (\S+) set the topic to:?\s*(.*)$/) {
            $hash{nick} = $1;
            my $topic = $2;
            # Remove surrounding brackets if present
            $topic =~ s/^\[//;
            $topic =~ s/\]$//;
            $hash{newtopic} = $topic;
            return \%hash;
        }

        # Mode change: * nick set +o target  or  * nick set -o target
        # Can also be multiple: * nick set +oo target1 target2
        if ($rest =~ /^\* (\S+) set ([+-][a-zA-Z]+)\s+(.+)$/) {
            $hash{nick} = $1;
            $hash{newmode} = $2;
            $hash{modechanges} = $3;
            return \%hash;
        }

        #
        # ZNC/energymech format support (*** prefix style)
        # This allows mixing ZNC live logs with IRCCloud historical logs
        #

        # ZNC Join: *** Joins: nick (host)
        if ($rest =~ /^\*\*\* Joins: (\S+)/) {
            $hash{nick} = $1;
            $hash{newjoin} = $1;
            add_valid_nick($1);
            return \%hash;
        }

        # ZNC Quit: *** Quits: nick (reason)
        if ($rest =~ /^\*\*\* Quits: (\S+)/) {
            $hash{nick} = $1;
            return \%hash;
        }

        # ZNC Part: *** Parts: nick (reason)
        if ($rest =~ /^\*\*\* Parts: (\S+)/) {
            $hash{nick} = $1;
            return \%hash;
        }

        # ZNC Nick change: *** nick is now known as newnick
        if ($rest =~ /^\*\*\* (\S+) is now known as (\S+)/) {
            $hash{nick} = $1;
            $hash{newnick} = $2;
            add_valid_nick($1);
            add_valid_nick($2);
            return \%hash;
        }

        # ZNC Kick: *** nick was kicked by kicker (reason)
        if ($rest =~ /^\*\*\* (\S+) was kicked by (\S+)\s*(.*)$/) {
            $hash{nick} = $1;
            $hash{kicker} = $2;
            my $reason = $3 || '';
            $reason =~ s/^\(//;
            $reason =~ s/\)$//;
            $hash{kicktext} = $reason;
            return \%hash;
        }

        # ZNC Topic: *** nick changes topic to 'new topic'
        if ($rest =~ /^\*\*\* (\S+) changes topic to '?(.*?)'?$/) {
            $hash{nick} = $1;
            $hash{newtopic} = $2;
            return \%hash;
        }

        # ZNC Mode: *** nick sets mode: +o target
        if ($rest =~ /^\*\*\* (\S+) sets mode: ([+-]\S+)\s*(.*)$/) {
            $hash{nick} = $1;
            $hash{newmode} = $2;
            $hash{modechanges} = $3 if $3;
            return \%hash;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
