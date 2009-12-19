package Getopt::Flex::Config;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

#valid non_option_mode arguments
enum 'NonOptionMode' => qw(IGNORE STOP);
 
#valid long_option_mode arguments           
enum 'LongOptionMode' => qw(REQUIRE_DOUBLE_DASH SINGLE_OR_DOUBLE);

#how to react when encountering something that
#isn't an option
has 'non_option_mode' => (
    is => 'ro',
    isa => 'NonOptionMode',
    default => 'IGNORE',
    writer => '_set_non_option_mode',
    predicate => '_has_non_option_mode',
);
 
#allow bundling to be used? automatically
#sets long_option_mode to REQUIRE_DOUBLE_DASH
#if set to true
has 'bundling' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);
                
#what kind of dashes are expected for
#long options
has 'long_option_mode' => (
    is => 'ro',
    isa => 'LongOptionMode',
    default => 'REQUIRE_DOUBLE_DASH',
    writer => '_set_long_option_mode',
);
                    
#how do I use this thing?
has 'usage' => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

#what is this thing like?
has 'desc' => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

=head1 NAME

Getopt::Flex::Config - Configuration class for Getopt::Flex

=head1 METHODS

=head2 BUILD

This method is used by Moose, please do not attempt to use it

=cut
                        
sub BUILD {
    my ($self) = @_;
    
    #automatically set the long_option_mode
    if($self->bundling) {
        $self->_set_long_option_mode('REQUIRE_DOUBLE_DASH');
    }
    
    #if POSIXLY_CORRECT set the non option mode to stop
    if($ENV{'POSIXLY_CORRECT'} && !$self->_has_non_option_mode) {
        $self->_set_non_option_mode('STOP');
    }
}

no Moose;

1;
