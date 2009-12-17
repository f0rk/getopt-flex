package Getopt::Flex::Config;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

enum 'NonOptionMode' => qw(IGNORE STOP);
            
enum 'LongOptionMode' => qw(REQUIRE_DOUBLE_DASH SINGLE_OR_DOUBLE);

has 'non_option_mode' => ( is => 'ro',
                           isa => 'NonOptionMode',
                           default => 'IGNORE',
                           writer => '_set_non_option_mode',
                           predicate => '_has_non_option_mode',
                        );
    
has 'bundling' => ( is => 'ro',
                    isa => 'Int',
                    default => 0,
                );
                
has 'ignore_case' => ( is => 'ro',
                       isa => 'Int',
                       default => 0,
                    );
                    
has 'long_option_mode' => ( is => 'ro',
                            isa => 'LongOptionMode',
                            default => 'REQUIRE_DOUBLE_DASH',
                            writer => '_set_long_option_mode',
                        );

=head1 NAME

Getopt::Flex::Config - Configuration class for Getopt::Flex

=head1 METHODS

=head2 BUILD

This method is used by Moose, please do not attempt to use it

=cut
                        
sub BUILD {
    my ($self) = @_;
    
    if($self->bundling) {
        $self->_set_long_option_mode('REQUIRE_DOUBLE_DASH');
    }
    
    if($ENV{'POSIXLY_CORRECT'} && !$self->_has_non_option_mode) {
        $self->_set_non_option_mode('REQUIRE_ORDER');
    }
}

no Moose;

1;
