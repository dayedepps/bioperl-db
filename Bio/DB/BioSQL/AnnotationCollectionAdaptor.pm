# $Id$

#
# BioPerl module for Bio::DB::BioSQL::AnnotationCollectionAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# 
# Version 1.42 and up are also
# (c) Hilmar Lapp, hlapp at gmx.net, 2002.
# (c) GNF, Genomics Institute of the Novartis Research Foundation, 2002.
#
# You may distribute this module under the same terms as perl itself.
# Refer to the Perl Artistic License (see the license accompanying this
# software package, or see http://www.perl.com/language/misc/Artistic.html)
# for the terms under which you may use, modify, and redistribute this module.
# 
# THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#

# POD documentation - main docs before the code

=head1 NAME

Bio::DB::BioSQL::AnnotationCollectionAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this
and other Bioperl modules. Send your comments and suggestions preferably
 to one of the Bioperl mailing lists.
Your participation is much appreciated.

  bioperl-l@bio.perl.org

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
 the bugs and their resolution.
 Bug reports can be submitted via email or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Ewan Birney, Hilmar Lapp

Email birney@ebi.ac.uk
Email hlapp at gmx.net

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::DB::BioSQL::AnnotationCollectionAdaptor;
use vars qw(@ISA);
use strict;

use Bio::DB::Query::PrebuiltResult;
use Bio::DB::BioSQL::BasePersistenceAdaptor;

@ISA = qw(Bio::DB::BioSQL::BasePersistenceAdaptor);

our %annotation_type_map = (
	"Bio::Annotation::DBLink"      => {
	    "key"      => "dblink",
	    "link"     => "association",
	},
	"Bio::Annotation::Reference"   => {
	    "key"      => "reference",
	    "link"     => "association",
	},
	"Bio::Annotation::SimpleValue" => {
	    "key"      => "dummy",
	    "link"     => "association",
	},
	"Bio::Annotation::Comment"     => {
	    "key"      => "comment",
	    "link"     => "child",
	}
			    );

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::DB::BioSQL::AnnotationCollectionAdaptor();
 Function: Builds a new Bio::DB::BioSQL::AnnotationCollectionAdaptor object 
 Returns : an instance of Bio::DB::BioSQL::AnnotationCollectionAdaptor
 Args    :


=cut

sub new {
    my($class,@args) = @_;

    my $self = $class->SUPER::new(@args);
    
    $self->_supported_annotation_map(\%annotation_type_map);

    return $self;
}


=head2 get_foreign_key_objects

 Title   : get_foreign_key_objects
 Usage   :
 Function: Gets the objects referenced by this object, and which therefore need
           to be referenced as foreign keys in the datastore.

           Note that the objects are expected to implement
           Bio::DB::PersistentObjectI.

           An implementation may obtain the values either through the
           object to be serialized, or through the additional
           arguments. An implementation should also make sure that the
           order of foreign key objects returned is always the same.

 Example :
 Returns : an array of Bio::DB::PersistentObjectI implementing objects
 Args    : The object about to be inserted or updated, or undef if the call
           is for a SELECT query. In the latter case return class or interface
           names that are mapped to the foreign key tables.
           Optionally, additional named parameters. A common parameter will
           be -fkobjs, with a reference to an array of foreign key objects
           that are not retrievable from the persistent object itself.

=cut

sub get_foreign_key_objects{
    my ($self,$obj,@args) = @_;
    my $annotatable;

    # we need to get this from the arguments.
    my ($fkobjs) = $self->_rearrange([qw(FKOBJS)], @args);
    if($fkobjs && @$fkobjs) {
	($annotatable) = grep {
	    $_->isa("Bio::SeqI") || (! ref($_));
	} @$fkobjs;
    } else {
	$annotatable = "Bio::SeqI";
    }

    return ($annotatable);
}

=head2 store_children

 Title   : store_children
 Usage   :
 Function: Inserts or updates the child entities of the given object in the 
           datastore.
 Example :
 Returns : TRUE on success, and FALSE otherwise
 Args    : The Bio::DB::PersistentObjectI implementing object for which the
           child objects shall be made persistent.
           A reference to an array of foreign key values, in the order of
           foreign keys returned by get_foreign_key_objects().


=cut

sub store_children{
    my ($self,$ac,$fkobjs) = @_;
    my $ok = 1;

    # get the annotation type map
    my $annotmap = $self->_supported_annotation_map();
    # we need to store the contained annotations
    foreach my $annkey ($ac->get_all_annotation_keys()) {
	my $rank = 0;
	foreach my $ann ($ac->get_Annotations($annkey)) {
	    # if it's a persistent object, store it
	    if($ann->isa("Bio::DB::PersistentObjectI")) {
		my @params = ();
		# if this is a child relationship by FK, we need to pass on
		# the FK here, and also supply the rank in case it's needed
		my $key = $self->_annotation_map_key($annotmap,$ann);
		if($annotmap->{$key}->{"link"} eq "child") {
		    $ann->rank(++$rank);
		    push(@params, -fkobjs => $fkobjs);
		}
		# now store the annotation object
		$ok = $ann->store(@params) && $ok;
	    }
	}
    }
    return $ok;
}

=head1 Inherited methods

We override a couple of inherited methods here because an AnnotationCollection
currently is only a virtual entity in the database. Hence, a number of
operations greatly reduce or don't make sense at all.

=head2 remove

 Title   : remove
 Usage   : $objectstoreadp->remove($persistent_obj, @params)
 Function: Removes the persistent object from the datastore.
 Example :
 Returns : TRUE on success and FALSE otherwise
 Args    : The object to be removed, and optionally additional (named) 
           parameters.


=cut

sub remove{
    my ($self,$obj,@args) = @_;

    $self->throw("Object of class ".ref($obj)." does not implement ".
		 "Bio::DB::PersistentObjectI. Bad, cannot remove.")
	if ! $obj->isa("Bio::DB::PersistentObjectI");
    # first off, delete from cache
    $self->_remove_from_obj_cache($obj);
    # the rest is not implemented yet
    $self->throw_not_implemented();
    # undefine the objects primary key - it doesn't exist in the datastore any
    # longer
    $obj->primary_key(undef);
}

=head2 find_by_primary_key

 Title   : find_by_primary_key
 Usage   : $objectstoreadp->find_by_primary_key($pk)
 Function: Locates the entry associated with the given primary key and
           initializes a persistent object with that entry.

           AnnotationCollection is not an entity in the database and hence
           this method doesn''t make sense. We just throw an exception here.
 Example :
 Returns : 
 Args    : 


=cut

sub find_by_primary_key{
    my ($self,$dbid,$fact) = @_;
    $self->throw("AnnotationCollectionI is a virtual entity, ".
		 "cannot find by primary key");
}

=head2 find_by_unique_key

 Title   : find_by_unique_key
 Usage   :
 Function: Locates the entry matching the unique key attributes as set in the
           passed object, and populates a persistent object with this entry.

           AnnotationCollection is not an entity in the database and hence
           this method doesn''t make sense. We just throw an exception here.
 Example :
 Returns : 
 Args    : 


=cut

sub find_by_unique_key{
    my ($self,$obj,@args) = @_;
    $self->throw("AnnotationCollectionI is a virtual entity, ".
		 "cannot find by unique key");
}

=head2 add_association

 Title   : add_assocation
 Usage   :
 Function: Stores the association between given objects in the datastore.

           We override this here in order to propagate associations of the
           AnnotationCollection to all the annotations it contains.
 Example :
 Returns : TRUE on success and FALSE otherwise
 Args    : Named parameters. At least the following must be recognized:
               -objs   a reference to an array of objects to be associated with
                       each other
               -values a reference to a hash the keys of which are abstract
                       column names and the values are values of those columns.
                       These columns are generally those other than
                       the ones for foreign keys to the entities to be
                       associated
               -obj_contexts optional, if given it denotes a reference to an
                       array of context keys (strings), which allow the
                       foreign key name to be determined through the
                       association map rather than through foreign_key_name().
                       This is necessary if more than one object of the same
                       type takes part in the association. The array must be
                       in the same order as -objs, and have the same number
                       of elements. Put "default" for objects for which there
                       are no multiple contexts.
  Caveats: Make sure you *always* give the objects to be associated in the
           same order.


=cut

sub add_association{
    my ($self,@args) = @_;
    my $ok = 1;

    # get arguments; we only need -objs and keep the rest untouched
    my %params = @args;
    my $objs = $params{-objs} || $params{-OBJS};
    # separate objects to be associated into AnnotationCollectionIs and others
    my $ac;
    my $i = 0;
    while($i < @$objs) {
	if($objs->[$i]->isa("Bio::AnnotationCollectionI")) {
	    $ac = $objs->[$i];
	    splice(@$objs, $i, 1); # remove the AnnotationCollection
	    last;
	}
	$i++;
    }
    if(! $ac) {
	$self->throw("This adaptor wants to associate with ".
		     "AnnotationCollectionIs, but there is none. Too bad.");
    }
    # get annotation type map
    my $annotmap = $self->_supported_annotation_map();
    # loop over all annotations in the collection and associate the
    # "other" objects with it
    foreach my $annkey ($ac->get_all_annotation_keys()) {
	my $rank = 0; # we count key-wise (i.e., term-wise)
	foreach my $ann ($ac->get_Annotations($annkey)) {
	    # if it's a persistent object, and if it's a membership by
	    # association, then propagate the association
	    if($ann->isa("Bio::DB::PersistentObjectI")) {
		my $key = $self->_annotation_map_key($annotmap,$ann);
		if($annotmap->{$key}->{"link"} eq "association") {
		    $ann->rank(++$rank);
		    push(@$objs, $ann);
		    $params{-values} = {"rank" => $ann->rank()};
		    $ok = $ann->adaptor()->add_association(%params) && $ok;
		    pop(@$objs);
		}
	    }
	}
    }
    # return and'ed result
    return $ok;
}

=head2 find_by_association

 Title   : find_by_association
 Usage   :
 Function: Locates those records associated between a number of objects. The
           focus object (the type to be instantiated) depends on the adaptor
           class that inherited from this class.

           We override this here to propagate this to all possible annotations.
 Example :
 Returns : A Bio::DB::Query::QueryResultI implementing object 
 Args    : Named parameters. At least the following must be recognized:
               -objs   a reference to an array of objects to be associated with
                       each other
               -obj_factory the factory to use for instantiating the
                       AnnotationCollectionI implementation.
  Caveats: Make sure you *always* give the objects to be associated in the
           same order.


=cut

sub find_by_association{
    my ($self,@args) = @_;

    # get arguments; we only need -objs and keep the rest untouched
    my %params = @args;
    my $objs = $params{-objs} || $params{-OBJS};
    # separate objects to be associated into AnnotationCollectionI and others
    my $ac;
    my $i = 0;
    while($i < @$objs) {
	if($objs->[$i]->isa("Bio::AnnotationCollectionI") ||
	   $objs->[$i]->isa(ref($self)) ||
	   ($objs->[$i] eq "Bio::AnnotationCollectionI")) {
	    $ac = $objs->[$i];
	    splice(@$objs, $i, 1); # remove the AnnotationCollection
	    last;
	}
	$i++;
    }
    # make sure we have an instantiated AnnotationCollectionI
    if(! (ref($ac) && $ac->isa("Bio::AnnotationCollectionI"))) {
	my $fact = $params{-obj_factory} || $params{-OBJ_FACTORY};
	$ac = $fact ?
	    $fact->create_object() : Bio::Annotation::Collection->new();
    }
    delete $params{-obj_factory};
    delete $params{-OBJ_FACTORY};
    # obtain the map from annotation types to annotation keys
    my $annotmap = $self->_supported_annotation_map();
    # loop over all supported annotations and find the ones associated
    # with the "other" objects
    my $foundanything = 0;
    foreach my $anntype (keys %$annotmap) {
	# we only do this for association links
	next unless $annotmap->{$anntype}->{"link"} eq "association";
	# ok, this is linked by association
	my $annadp = $self->db()->get_object_adaptor($anntype);
	# temporarily add the type to the array of objects to be associated
	push(@$objs, $anntype);
	# get query result
	my $qres = $annadp->find_by_association(%params);
	# loop over all result objects and attach
	while(my $ann = $qres->next_object()) {
	    # tagname may come from the db - otherwise set it from the map
	    $ann->tagname($annotmap->{$anntype}->{"key"}) if ! $ann->tagname();
	    $ac->add_Annotation($ann);
	    $foundanything = 1;
	}
	# restore object array
	pop(@$objs);
    }
    # return a prebuilt query result to be compatible with the expected
    # return type
    return $foundanything ?
	Bio::DB::Query::PrebuiltResult->new(-objs => [$ac]) :
	Bio::DB::Query::PrebuiltResult->new(-objs => []);
}

=head2 remove_children

 Title   : remove_children
 Usage   :
 Function: This method is to cascade deletes in maintained objects.

           We need to undefine the primary keys of all contained
           children objects here.

 Example :
 Returns : TRUE on success and FALSE otherwise
 Args    : The persistent object that was just removed from the database.
           Additional (named) parameter, as passed to remove().


=cut

sub remove_children{
    my $self = shift;
    my $ac = shift;

    # get the annotation type map
    my $annotmap = $self->_supported_annotation_map();
    # check annotation for each key
    foreach my $annkey ($ac->get_all_annotation_keys()) {
	foreach my $ann ($ac->get_Annotations($annkey)) {
	    if($ann->isa("Bio::DB::PersistentObjectI")) {
		# undef the PK if this is a child relationship by FK
		my $key = $self->_annotation_map_key($annotmap,$ann);
		if($annotmap->{$key}->{"link"} eq "child") {
		    $ann->primary_key(undef);
		    # cascade through in case the object needs it
		    $ann->adaptor->remove_children($ann);
		}
	    }
	}
    }
    # done
    return 1;
}

=head2 _supported_annotation_map

 Title   : _supported_annotation_map
 Usage   : $obj->_supported_annotation_map($newval)
 Function: Get/set the map of supported annotation types (implementing
	   classes) to annotation keys and persistence arguments.

           The values of the map are anonymous hashes themselves with
           currently the following keys and values.
             key     the annotation collection key for this type of
                     annotation
             link    the type of link between the collection and the
                     annotation object (child or association)

 Example : 
 Returns : value of _supported_annotation_map (a reference to hash map)
 Args    : new value (a reference to a hash map)


=cut

sub _supported_annotation_map{
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'supported_annotations'} = $value;
    }
    return $self->{'supported_annotations'};
}

sub _annotation_map_key{
    my ($self,$map,$obj) = @_;
    my $key = ref($obj->obj());
    if(! exists($map->{$key})) {
	($key) = grep { $obj->isa($_); } keys %$map;
	# cache result
	if($key) {
	    $map->{ref($obj->obj())} = $map->{$key};
	} else {
	    $self->throw("Annotation of class ".ref($obj->obj).
			 " not type-mapped. Internal error?");
	}
    }
    return $key;
}

1;