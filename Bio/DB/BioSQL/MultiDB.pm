# Adaptor for Multiple BioSQL databases.
# By Juguang Xiao <juguang@tll.org.sg> 

=head1 NAME

    Bio::DB::BioSQL::MultiDB

=head1 DESCRIPTION

The scalability issue will arise, when multiple huge bio databases are loaded
in a single database in RDBMS, due to the scalability of the RDBMS. So one 
solution to solve it is simply to distribute them into multiple physical 
database, while I expect to manage them by one logic adaptor.

So here you go, MultiDB aims at such issue to solve. The way to apply that is
pretty simple. You, first, load data from different biodatabase, such as 
swissprot or embl, into physical RDBMS databases; then create a db adaptor 
for each simple physical biosql db; finally register these adaptors into 
MultiDB and use it as that was a normal dbadaptor.

=head1 USAGE

use Bio::DB::BioSQL::MultiDB;

# create the common biosql db adaptors
my $swissprot_db;  # Physical databases may be located on different servers
my $embl_db;       # or accessible by different users.

# register them by bio-database
my $multiDB = Bio::DB::BioSQL::MultiDB->new(
    'swissprot' => $swissprot_db,
    'embl' => $embl_db
);

# Each time before you want to create a persistent object for Bio::Seq,
# assign the 'namescape' sub of seq object first, as the biodatabase name.
my $seq;    # for either store or fetch.
$seq->namespace('swissprot');

# OR you need to assign the default namespace for multiDB
$multiDB->namespace('swissport');

my $pseq = $multiDB->create_persistent($seq);
$pseq->store;

=cut 

package Bio::DB::BioSQL::MultiDB;

use strict;
use vars qw(@ISA);

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

=cut 

sub new{
    my ($class, @args) = @_;
    my %dbs = @args;
    my $self = $class->SUPER::new(@args); 

    foreach (keys %dbs){
        $self->_namespace_dbs($_, $dbs{$_});
    }
    return $self;
}

sub _namespace_dbs{
    my ($self, $key, $value) = @_;
    $self->{_namespace_dbs} = {} unless $self->{_namespace_dbs};
    if (exists $self->{_namespace_dbs}->{$key}){
		return $self->{_namespace_dbs}->{$key};
	}elsif(!defined $value){
		$self->throw("Cannot find \'$key\' as namespace. It may not regiested");
	}

    return $self->{_namespace_dbs}->{$key} = $value if $value;

}

=head2 create_persistent

This method offers the same interface as Bio::DB::BioSQL::DBAdaptor, hence the
usage is same as well.

NOTE: You need to assign $obj->namespace as the biodatabase name, such as embl,
before you invoke this method.

=cut

sub create_persistent{
    my ($self,$obj,@args) = @_;

    # The object instant creation is copy from Bio::DB::BioSQL::DBAdaptor

    # we need to obtain an instance of the class 
    # if it's not already an instance
    if(! ref($obj)) {
        my $class = $obj;
        # load the module first, otherwise new() will fail;
        # this will throw an exception if it fails
        $self->_load_module($class);
        # we wrap this in an eval in order to indicate clearer what failed
        # (if it fails)
        eval {
            $obj = $class->new(@args);
        };
        if($@){
            $self->throw("Failed to instantiate ${obj}: ".$@);
        }
    }

    # The end of coping and here is my code.
    # Try to get namespace
    my $namespace;
    if($obj->isa('Bio::Seq') or $obj->can('namespace')){
        $namespace = $obj->namespace;
    }elsif(defined $self->namespace){
        $namespace = $self->namespace;
    }else{
        $self->throw('The module, '. ref($obj). ', is not supported');
    }

    my $db = $self->_namespace_dbs($namespace);
    return $db->create_persistent($obj);
    
}

sub get_object_adaptor{
    my ($self, $class, $dbc) = @_;
    my ($adp, $adpclass);

    my $namespace;
    if( ref $class){
        if( $class->can('namespace')){
            $namespace = $class->namespace;
        }else{
            $namespace = $self->namespace;
        }
        $class = ref $class;
    }else{
        $namespace = $self->namespace;
    }

    my $db = $self->_namespace_dbs($namespace);
    $adpclass = $db->get_object_adaptor($class, $dbc);

    return $adpclass;
}

=head2

Get/Set for default namespace

=cut

sub namespace{
    my ($self, $value) = @_;
    return $self->{'_namespace'} = $value if defined $value;
    return $self->{'_namespace'};
}


