#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 12;
use lib 'modules';

use_ok('Pisg::Parser::Format::energymech');

# Create parser with bridge nicks configured
my $parser = Pisg::Parser::Format::energymech->new(
    cfg => { bridgenicks => 'discordsync discordsync` discordsync``' }
);

ok($parser, 'Parser created');

# Test 1: Normal message (non-bridge)
{
    my $result = $parser->normalline('[2026-02-04 23:01:23] <RustyCloud> hello world', 1);
    ok($result, 'Normal message parsed');
    is($result->{nick}, 'RustyCloud', 'Normal nick extracted');
    is($result->{saying}, 'hello world', 'Normal message extracted');
}

# Test 2: Bridge message with backticks variant
{
    my $result = $parser->normalline('[2026-02-04 23:04:12] <discordsync``> <Virtual-Potato> test message', 1);
    ok($result, 'Bridge message parsed');
    is($result->{nick}, 'Virtual-Potato', 'Bridge nick extracted');
    is($result->{saying}, 'test message', 'Bridge message extracted');
}

# Test 3: Bridge message with IRC color codes
{
    # \x03 is IRC color code, 13 is the color number
    my $line = "[2026-02-04 23:04:12] <discordsync\`\`> <\x0313Virtual-Potato\x0f> colored message";
    my $result = $parser->normalline($line, 1);
    ok($result, 'Bridge message with color codes parsed');
    is($result->{nick}, 'Virtual-Potato', 'Nick extracted after stripping color codes');
}

# Test 4: Bridge message with zero-width characters
{
    # \x{200b} is zero-width space
    my $line = "[2026-02-04 23:04:12] <discordsync\`\`> <Vir\x{200b}tual-\x{200b}Potato> zwsp message";
    my $result = $parser->normalline($line, 1);
    ok($result, 'Bridge message with zero-width chars parsed');
    is($result->{nick}, 'Virtual-Potato', 'Nick extracted after stripping zero-width chars');
}

done_testing();
