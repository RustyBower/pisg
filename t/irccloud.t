#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'modules';

use_ok('Pisg::Parser::Format::irccloud');

my $parser = Pisg::Parser::Format::irccloud->new(
    cfg => { bridgenicks => 'discordsync' }
);
ok($parser, 'Parser created');

# --- normalline tests ---

# Normal message
{
    my $result = $parser->normalline('[2017-01-03 16:24:51] <Rusty> hello world', 1);
    ok($result, 'Normal message parsed');
    is($result->{nick}, 'Rusty', 'Normal nick extracted');
    is($result->{saying}, 'hello world', 'Normal saying extracted');
    is($result->{hour}, '16', 'Hour extracted');
}

# Bridge nick message
{
    my $result = $parser->normalline('[2017-01-03 16:24:51] <discordsync> <R3cursive> hey there', 1);
    ok($result, 'Bridge message parsed');
    is($result->{nick}, 'R3cursive', 'Bridge real nick extracted');
    is($result->{saying}, 'hey there', 'Bridge message extracted');
}

# Bridge nick with @ prefix
{
    my $result = $parser->normalline('[2017-01-03 16:24:51] <discordsync> <@AdminUser> admin says hi', 1);
    ok($result, 'Bridge message with @ prefix parsed');
    is($result->{nick}, 'AdminUser', 'Bridge nick @ prefix stripped');
}

# Bridge nick with no real nick - should return undef
{
    my $result = $parser->normalline('[2017-01-03 16:24:51] <discordsync> random text no brackets', 1);
    ok(!$result, 'Bridge message without <nick> format returns undef');
}

# --- actionline tests: standard * format ---

# Standard /me action with asterisk
{
    my $result = $parser->actionline("[2017-01-03 16:24:51] * Rusty does something", 1);
    ok($result, 'Standard * action parsed');
    is($result->{nick}, 'Rusty', 'Action nick extracted');
    is($result->{saying}, 'does something', 'Action saying extracted');
    is($result->{hour}, '16', 'Action hour extracted');
}

# Kick line should be skipped (handled by thirdline)
{
    my $result = $parser->actionline("[2017-01-03 16:24:51] * someone was kicked by Rusty (reason)", 1);
    ok(!$result, 'Kick line skipped in actionline');
}

# Topic line should be skipped
{
    my $result = $parser->actionline("[2017-01-03 16:24:51] * Rusty set the topic to something", 1);
    ok(!$result, 'Topic line skipped in actionline');
}

# Mode line should be skipped
{
    my $result = $parser->actionline("[2017-01-03 16:24:51] * Rusty set +o BotSaget", 1);
    ok(!$result, 'Mode line skipped in actionline');
}

# IRCCloud system messages should be skipped
{
    my $result = $parser->actionline("[2017-01-03 16:24:51] * Channel mode is +snt", 1);
    ok(!$result, 'Channel mode system message skipped');
}
{
    my $result = $parser->actionline("[2017-01-03 16:24:51] * Socket closed", 1);
    ok(!$result, 'Socket closed system message skipped');
}

# --- actionline tests: em-dash format (the bug fix!) ---

# Em-dash /me action
{
    my $result = $parser->actionline("[2014-09-19 23:34:04] \xe2\x80\x94 Drewbie slaps Airman", 1);
    ok($result, 'Em-dash action parsed');
    is($result->{nick}, 'Drewbie', 'Em-dash action nick extracted');
    is($result->{saying}, 'slaps Airman', 'Em-dash action saying extracted');
    is($result->{hour}, '23', 'Em-dash action hour extracted');
}

# Em-dash violence action with longer text
{
    my $result = $parser->actionline("[2014-10-16 11:40:03] \xe2\x80\x94 chugdiesel beats MXP", 1);
    ok($result, 'Em-dash violence action parsed');
    is($result->{nick}, 'chugdiesel', 'Violence action nick');
    is($result->{saying}, 'beats MXP', 'Violence action saying');
}

# Em-dash non-violent action
{
    my $result = $parser->actionline("[2014-05-03 02:17:11] \xe2\x80\x94 profit np - goose - black gloves", 1);
    ok($result, 'Em-dash regular action parsed');
    is($result->{nick}, 'profit', 'Regular em-dash action nick');
}

# Em-dash nick change should be skipped (handled by thirdline)
{
    my $result = $parser->actionline("[2014-06-06 16:10:13] \xe2\x80\x94 skud is now known as skud|away", 1);
    ok(!$result, 'Em-dash nick change skipped in actionline');
}

# --- thirdline tests ---

# Join
{
    my $result = $parser->thirdline("[2017-01-03 15:54:21] \xe2\x86\x92 discordsync joined (host\@ip)", 1);
    ok($result, 'Join parsed');
    is($result->{nick}, 'discordsync', 'Join nick extracted');
    is($result->{newjoin}, 'discordsync', 'newjoin set');
}

# Quit
{
    my $result = $parser->thirdline("[2017-01-03 15:54:33] \xe2\x87\x90 discordsync quit (host\@ip): Read error", 1);
    ok($result, 'Quit parsed');
    is($result->{nick}, 'discordsync', 'Quit nick extracted');
}

# Part
{
    my $result = $parser->thirdline("[2017-01-03 15:54:33] \xe2\x86\x90 someone left (host\@ip): bye", 1);
    ok($result, 'Part parsed');
    is($result->{nick}, 'someone', 'Part nick extracted');
}

# Nick change (em-dash format)
{
    my $result = $parser->thirdline("[2014-06-06 16:10:13] \xe2\x80\x94 skud is now known as skud|away", 1);
    ok($result, 'Nick change parsed in thirdline');
    is($result->{nick}, 'skud', 'Nick change old nick');
    is($result->{newnick}, 'skud|away', 'Nick change new nick');
}

# Kick
{
    my $result = $parser->thirdline("[2014-05-08 20:44:28] * Friss was kicked by RustyCloud (dont be dumb)", 1);
    ok($result, 'Kick parsed');
    is($result->{nick}, 'Friss', 'Kick victim nick');
    is($result->{kicker}, 'RustyCloud', 'Kicker nick');
    is($result->{kicktext}, 'dont be dumb', 'Kick reason');
}

# Topic
{
    my $result = $parser->thirdline("[2014-09-10 17:41:49] * RustyCloud set the topic to Welcome to the channel", 1);
    ok($result, 'Topic change parsed');
    is($result->{nick}, 'RustyCloud', 'Topic changer nick');
    is($result->{newtopic}, 'Welcome to the channel', 'Topic text');
}

# ZNC join
{
    my $result = $parser->thirdline("[2017-01-03 15:54:21] *** Joins: testuser (host\@ip)", 1);
    ok($result, 'ZNC join parsed');
    is($result->{nick}, 'testuser', 'ZNC join nick');
    is($result->{newjoin}, 'testuser', 'ZNC newjoin set');
}

# ZNC quit
{
    my $result = $parser->thirdline("[2017-01-03 15:54:21] *** Quits: testuser (reason)", 1);
    ok($result, 'ZNC quit parsed');
    is($result->{nick}, 'testuser', 'ZNC quit nick');
}

# ZNC kick
{
    my $result = $parser->thirdline("[2017-01-03 15:54:21] *** testuser was kicked by admin (bad behavior)", 1);
    ok($result, 'ZNC kick parsed');
    is($result->{nick}, 'testuser', 'ZNC kick victim');
    is($result->{kicker}, 'admin', 'ZNC kicker');
}

done_testing();
