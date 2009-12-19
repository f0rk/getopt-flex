use strict;
use warnings;
use Test::More tests => 27;
use Test::Exception;
use Getopt::Flex;

my $foo;
my @arr;
my %has;

my $cfg = {
    'non_option_mode' => 'STOP', 
};

my $sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Str',
    }
};

$foo = 'bar';
my $op = Getopt::Flex->new({spec => $sp, config => $cfg});
my @args = qw(--foo baz);
$op->set_args(\@args);
$op->getopts();
is($foo, 'baz', '--foo set with baz');

$foo = 'bar';
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(cast --foo baz);
$op->set_args(\@args);
$op->getopts();
is($foo, 'bar', '--foo left unset with bar');

$sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Int',
        'required' => 1,
    }
};

$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f 10 -f 12);
$op->set_args(\@args);
$op->getopts();
is($foo, 12, '-f set with 12');

$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(cast -f 10 -f 12);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with required switch not supplied';

$sp = {
    'foo|f' => {
        'var' => \@arr,
        'type' => 'ArrayRef[Str]',
    }  
};

@arr = ();
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f a -f b -f c);
$op->set_args(\@args);
$op->getopts();
is($#arr, 2, 'arr set with 3 values');
is($arr[0], 'a', 'arr has 0th elem a');
is($arr[1], 'b', 'arr has 1st elem b');
is($arr[2], 'c', 'arr has 2nd elem c');

@arr = ();
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f a cast -f b -f c);
$op->set_args(\@args);
$op->getopts();
is($#arr, 0, 'arr set with 1 value');
is($arr[0], 'a', 'arr has 0th elem a');

$sp = {
    'foo|f' => {
        'var' => \%has,
        'type' => 'HashRef[Str]',
    }
};

%has = ();
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f aa=aa -f bb=bb -f cc=cc);
$op->set_args(\@args);
$op->getopts();
my @keys = sort keys %has;
is($#keys, 2, 'keys has 3 values');
is($keys[0], 'aa', 'keys has 0th elem aa');
is($keys[1], 'bb', 'keys has 1st elem bb');
is($keys[2], 'cc', 'keys has 2nd elem cc');
is($has{'aa'}, 'aa', 'key aa set with aa');
is($has{'bb'}, 'bb', 'key bb set with bb');
is($has{'cc'}, 'cc', 'key cc set with cc');

%has = ();
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f aa=aa cast -f bb=bb -f cc=cc);
$op->set_args(\@args);
$op->getopts();
@keys = sort keys %has;
is($#keys, 0, 'keys has 1 value');
is($keys[0], 'aa', 'keys has 0th elem aa');
is($has{'aa'}, 'aa', 'key aa set with aa');

$sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Int',
    }
};

$foo = 0;
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f 10 -foo);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with supplied value does not pass type constraint';

$foo = 0;
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f 10 --cfoo -f 20);
$op->set_args(\@args);
$op->getopts();
is($foo, 10, '-f set with 10');

$sp = {
    'foo|f' => {
        'var' => \@arr,
        'type' => 'ArrayRef[Str]',
    }
};

@arr = ();
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f cats --cfoo -f bats);
$op->set_args(\@args);
$op->getopts();
is($#arr, 0, 'arr set with 1 value');
is($arr[0], 'cats', '-f set with cats');

$sp = {
    'foo|f' => {
        'var' => \%has,
        'type' => 'HashRef[Str]',
    }
};

%has = ();
$op = Getopt::Flex->new({spec => $sp, config => $cfg});
@args = qw(-f aa=cats --cfoo -f bb=bats);
$op->set_args(\@args);
$op->getopts();
@keys = sort keys %has;
is($#keys, 0, 'keys set with 1 value');
is($keys[0], 'aa', 'keys has 0th elem aa');
is($has{'aa'}, 'cats', 'key aa set with cats');
