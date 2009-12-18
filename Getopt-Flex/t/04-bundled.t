use strict;
use warnings;
use Test::More tests => 12;
use Getopt::Flex;

my $foo;
my $bar;
my $cab;

my $sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Bool',
    },
    'bar|b' => {
        'var' => \$bar,
        'type' => 'Bool',
    },
    'cab|c' => {
        'var' => \$cab,
        'type' => 'Str',
    }
};

$foo = 0;
$bar = 0;
$cab = 0;
my $op = Getopt::Flex->new({spec => $sp});
my @args = qw(-fb -c=foo);
$op->set_args(\@args);
$op->getopts();
ok($foo, '-f set to true');
ok($bar, '-b set to true');
is($cab, 'foo', '-c set to foo');

$foo = 0;
$bar = 0;
$cab = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-fc=foo -b);
$op->set_args(\@args);
$op->getopts();
ok($foo, '-f set to true');
ok($bar, '-b set to true');
is($cab, 'foo', '-c set to foo');

$foo = 0;
$bar = 0;
$cab = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-fcfoo -b);
$op->set_args(\@args);
$op->getopts();
ok($foo, '-f set to true');
ok($bar, '-b set to true');
is($cab, 'foo', '-c set to foo');

$foo = 0;
$bar = 0;
$cab = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-fc foo -b);
$op->set_args(\@args);
$op->getopts();
ok($foo, '-f set to true');
ok($bar, '-b set to true');
is($cab, 'foo', '-c set to foo');
