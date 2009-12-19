use strict;
use warnings;
use Test::More tests => 102;
use Test::Exception;
use Getopt::Flex;

my $foo;
my $bar;
my @arr;
my %has;

my $sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Str',
    }
};

my $op = Getopt::Flex->new({spec => $sp});
my @args = qw(-f bar);
$op->set_args(\@args);
$op->getopts();
my @va = $op->get_valid_args();
my @ia = $op->get_invalid_args();
my @ea = $op->get_extra_args();
is($foo, 'bar', '-f set with bar');
is($#va, 0, 'va contains 1 value');
is($#ia, -1, 'ia contains 0 values');
is($#ea, -1, 'ea contains 0 values');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=baz);
$op->set_args(\@args);
$op->getopts();
@va = $op->get_valid_args();
@ia = $op->get_invalid_args();
@ea = $op->get_extra_args();
is($foo, 'baz', '-f set with baz');
is($#va, 0, 'va contains 1 value');
is($#ia, -1, 'ia contains 0 values');
is($#ea, -1, 'ea contains 0 values');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-fbag);
$op->set_args(\@args);
$op->getopts();
is($foo, 'bag', '-f set with bag');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f-boo);
$op->set_args(\@args);
$op->getopts();
is($foo, '-boo', '-f set with boo');

#add more switch specs
$sp = {
  'foo|f' => {
      'var' => \$foo,
      'type' => 'Str',
  },
  'bar|b' => {
      'var' => \$bar,
      'type' => 'Str',
  },
};

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aaa -b bbb);
$op->set_args(\@args);
$op->getopts();
@va = $op->get_valid_args();
@ia = $op->get_invalid_args();
@ea = $op->get_extra_args();
is($foo, 'aaa', '-f set with aaa');
is($bar, 'bbb', '-b set with bbb');
is($#va, 1, 'va contains 2 values');
is($#ia, -1, 'ia contains 0 values');
is($#ea, -1, 'ea contains 0 values');

#try out required
$sp = {
  'foo|f' => {
      'var' => \$foo,
      'type' => 'Str',
      'required' => 1,
  },
};

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f box);
$op->set_args(\@args);
lives_ok { $op->getopts() } 'Should not die';
is($foo, 'box', '-f set with box');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with argument -f requires a value';

$op = Getopt::Flex->new({spec => $sp});
@args = qw();
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with missing required argument -f';

#checking int values
$sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Int',
    }
};

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 1);
$op->set_args(\@args);
$op->getopts();
is($foo, 1, '-f set with 1');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f1);
$op->set_args(\@args);
$op->getopts();
is($foo, 1, '-f set with 1');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=1);
$op->set_args(\@args);
$op->getopts();
is($foo, 1, '-f set with 1');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 2e2);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Should die with value failing to pass type constraint';

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f2e2);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Should die with value failing to pass type constraint';

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=2e2);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Should die with value failing to pass type constraint';

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 2.2);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Should die with value failing to pass type constraint';

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f2.2);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Should die with value failing to pass type constraint';

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=2.2);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Should die with value failing to pass type constraint';

#test out bool
$sp = {
  'foo|f' => {
      'var' => \$foo,
      'type' => 'Bool',
  }  
};

$foo = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f);
$op->set_args(\@args);
$op->getopts();
ok($foo, '-f set to true');

$foo = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 0);
$op->set_args(\@args);
$op->getopts();
ok($foo, '-f set to true');
my @extra_args = $op->get_extra_args();
is($#extra_args, 0, 'Extra args has one element');
is($extra_args[0], 0, 'Extra args contains 0');

#test out num
$sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Num',
    }
};

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 0);
$op->set_args(\@args);
$op->getopts();
is($foo, 0, '-f set to 0');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f0);
$op->set_args(\@args);
$op->getopts();
is($foo, 0, '-f set to 0');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=0);
$op->set_args(\@args);
$op->getopts();
is($foo, 0, '-f set to 0');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 1);
$op->set_args(\@args);
$op->getopts();
is($foo, 1, '-f set to 1');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f1);
$op->set_args(\@args);
$op->getopts();
is($foo, 1, '-f set to 1');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=1);
$op->set_args(\@args);
$op->getopts();
is($foo, 1, '-f set to 1');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 2.2);
$op->set_args(\@args);
$op->getopts();
is($foo, 2.2, '-f set to 2.2');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=2.2);
$op->set_args(\@args);
$op->getopts();
is($foo, 2.2, '-f set to 2.2');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f2.2);
$op->set_args(\@args);
$op->getopts();
is($foo, 2.2, '-f set to 2.2');

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aaa);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=aaa);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';

$op = Getopt::Flex->new({spec => $sp});
@args = qw(-faaa);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';

#try incremental
$sp = {
    'foo|f' => {
        'var' => \$foo,
        'type' => 'Inc',
    }  
};

$foo = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f);
$op->set_args(\@args);
$op->getopts();
is($foo, 1, '-f should be 1');

$foo = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f -f);
$op->set_args(\@args);
$op->getopts();
is($foo, 2, '-f should be 2');

$foo = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw();
$op->set_args(\@args);
$op->getopts();
is($foo, 0, '-f should be 0');

$foo = 0;
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f -f -f -f -f);
$op->set_args(\@args);
$op->getopts();
is($foo, 5, '-f should be 5');

#try out arrays
$sp = {
    'foo|f' => {
        'var' => \@arr,
        'type' => 'ArrayRef[Str]',
    }
};

@arr = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw();
$op->set_args(\@args);
$op->getopts();
is($#arr, -1, '-f set with no values');

@arr = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa -f bb -f cc);
$op->set_args(\@args);
$op->getopts();
is($#arr, 2, '-f set with 3 values');
is($arr[0], 'aa', 'arr has 0th elem aa');
is($arr[1], 'bb', 'arr has 1st elem bb');
is($arr[2], 'cc', 'arr has 2nd elem cc');

$sp = {
    'foo|f' => {
        'var' => \@arr,
        'type' => 'ArrayRef[Int]',
    }
};

@arr = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 1 -f 2);
$op->set_args(\@args);
$op->getopts();
is($#arr, 1, '-f set with 2 values');
is($arr[0], 1, 'arr has 0th elem 1');
is($arr[1], 2, 'arr has 1st elem 2');

@arr = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 1 -f bar);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';

$sp = {
    'foo|f' => {
        'var' => \@arr,
        'type' => 'ArrayRef[Num]',
    }
};

@arr = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 1 -f 2);
$op->set_args(\@args);
$op->getopts();
is($#arr, 1, '-f set with 2 values');
is($arr[0], 1, 'arr has 0th elem 1');
is($arr[1], 2, 'arr has 1st elem 2');

@arr = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 1 -f 2.2);
$op->set_args(\@args);
$op->getopts();
is($#arr, 1, '-f set with 2 values');
is($arr[0], 1, 'arr has 0th elem 1');
is($arr[1], 2.2, 'arr has 1st elem 2.2');

@arr = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f 1 -f bar);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';

#try out hashes
$sp = {
  'foo|f' => {
      'var' => \%has,
      'type' => 'HashRef[Str]',
  }  
};

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa=foo -f bb=bar -f cc=baz);
$op->set_args(\@args);
$op->getopts();
my @keys = sort keys %has;
is($#keys, 2, 'has has 3 keys');
is($keys[0], 'aa', 'has key aa');
is($keys[1], 'bb', 'has key bb');
is($keys[2], 'cc', 'has key cc');
is($has{'aa'}, 'foo', 'key aa has val foo');
is($has{'bb'}, 'bar', 'key bb has val bar');
is($has{'cc'}, 'baz', 'key cc has val baz');

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f=aa=foo -f=bb=bar -f=cc=baz);
$op->set_args(\@args);
$op->getopts();
@keys = sort keys %has;
is($#keys, 2, 'has has 3 keys');
is($keys[0], 'aa', 'has key aa');
is($keys[1], 'bb', 'has key bb');
is($keys[2], 'cc', 'has key cc');
is($has{'aa'}, 'foo', 'key aa has val foo');
is($has{'bb'}, 'bar', 'key bb has val bar');
is($has{'cc'}, 'baz', 'key cc has val baz');

$sp = {
    'foo|f' => {
        'var' => \%has,
        'type' => 'HashRef[Int]',
    }
};

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa=1 -f bb=2 -f cc=3);
$op->set_args(\@args);
$op->getopts();
@keys = sort keys %has;
is($#keys, 2, 'has has 3 keys');
is($keys[0], 'aa', 'has key aa');
is($keys[1], 'bb', 'has key bb');
is($keys[2], 'cc', 'has key cc');
is($has{'aa'}, 1, 'key aa has val 1');
is($has{'bb'}, 2, 'key bb has val 2');
is($has{'cc'}, 3, 'key cc has val 3');

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa=1 -f bb=bar -f cc=3);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa=1 -f bb=2.2 -f cc=3);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';

$sp = {
    'foo|f' => {
        'var' => \%has,
        'type' => 'HashRef[Num]',
    }
};

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa=1 -f bb=2 -f cc=3);
$op->set_args(\@args);
$op->getopts();
@keys = sort keys %has;
is($#keys, 2, 'has has 3 keys');
is($keys[0], 'aa', 'has key aa');
is($keys[1], 'bb', 'has key bb');
is($keys[2], 'cc', 'has key cc');
is($has{'aa'}, 1, 'key aa has val 1');
is($has{'bb'}, 2, 'key bb has val 2');
is($has{'cc'}, 3, 'key cc has val 3');

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa=1.1 -f bb=2.2 -f cc=3.3);
$op->set_args(\@args);
$op->getopts();
@keys = sort keys %has;
is($#keys, 2, 'has has 3 keys');
is($keys[0], 'aa', 'has key aa');
is($keys[1], 'bb', 'has key bb');
is($keys[2], 'cc', 'has key cc');
is($has{'aa'}, 1.1, 'key aa has val 1.1');
is($has{'bb'}, 2.2, 'key bb has val 2.2');
is($has{'cc'}, 3.3, 'key cc has val 3.3');

%has = ();
$op = Getopt::Flex->new({spec => $sp});
@args = qw(-f aa=1 -f bb=bar -f cc=3);
$op->set_args(\@args);
dies_ok { $op->getopts() } 'Dies with value does not pass type constraint';
