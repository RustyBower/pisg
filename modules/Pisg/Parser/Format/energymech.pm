package Pisg::Parser::Format::energymech;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[[^\]]*(\d{2}):\d+:\d+\] <([^>]+)> (.*)$',
        actionline => '^\[[^\]]*(\d{2}):\d+:\d+\] \* (\S+) (.*)$',
        thirdline  => '^\[[^\]]*(\d{2}):(\d+):\d+\] \*{3} (.+)$'
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

        # BEGIN: BRIDGE NICK HANDLING
        my @bridge_nicks = split /\s+/, ($self->{cfg}->{bridgenicks} // '');

        # Use prefix matching for bridge nicks (e.g., "discordsync" matches "discordsync``")
        if (@bridge_nicks && grep { $hash{nick} =~ /^\Q$_\E/ } @bridge_nicks) {
            # Strip IRC formatting codes from the message first
            my $clean_saying = $hash{saying};
            $clean_saying =~ s/\x03\d{0,2}(?:,\d{1,2})?//g;  # IRC color codes
            $clean_saying =~ s/[\x02\x0f\x16\x1d\x1f]//g;     # bold, reset, reverse, italic, underline

            # Match bridged messages: <@nick> or <nick>
            if ($clean_saying =~ /^<@?([^>]+)>\s*(.*)$/) {
                my ($real_nick, $real_msg) = ($1, $2);

                # Clean nick: remove unicode format chars, normalize whitespace, keep valid IRC chars
                $real_nick =~ s/\p{Cf}//g;                              # Zero-width chars
                $real_nick =~ s/^\s+|\s+$//g;                           # Trim whitespace
                $real_nick =~ s/\s+/_/g;                                # Internal spaces to underscore
                $real_nick =~ s/[^a-zA-Z0-9_\-\[\]\\\^\{\}`|]//g;       # Keep only valid IRC nick chars

                # Only use if we got a valid nick
                if ($real_nick && length($real_nick) > 0) {
                    $hash{nick}   = $real_nick;
                    $hash{saying} = $real_msg;
                } else {
                    return;  # Invalid nick extracted
                }
            } else {
                return;  # Drop this line - doesn't match bridge format
            }
        }
        # END: BRIDGE NICK HANDLING

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

        my @line = split(/\s/, $3);

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $line[0];

        if ($#line >= 4 && ($line[1].$line[2]) eq 'waskicked') {
            $hash{kicker} = $line[4];
            $hash{kicktext} = $3;
            $hash{kicktext} =~ s/^[^\(]+\((.+)\)$/$1/;

        } elsif ($#line >= 4 && ($line[1].$line[2]) eq 'changestopic') {
            $hash{newtopic} = join(' ', @line[4..$#line]);
            $hash{newtopic} =~ s/^'//;
            $hash{newtopic} =~ s/'$//;

        } elsif ($#line >= 4 && ($line[1].$line[2]) eq 'setsmode:') {
            $hash{newmode} = $line[3];
            $hash{modechanges} = join(" ", splice(@line, 4));

        } elsif ($#line >= 1 && $line[0] eq 'Joins:') {
            $hash{nick} = $line[1];
            $hash{newjoin} = $line[1];
            
        } elsif ($#line >= 5 && ($line[2].$line[3]) eq 'nowknown') {
            $hash{newnick} = $line[5];
        }

        return \%hash;

    } else {
        return;
    }
}

1;
