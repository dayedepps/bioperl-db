

# conventions:
# <table_name>_id is primary internal id (usually autogenerated)


# database have bioentries. That's about the only restriction

CREATE TABLE biodatabase (
  biodatabase_id int(10) unsigned NOT NULL auto_increment,
  name        varchar(40) NOT NULL,
  PRIMARY KEY(biodatabase_id)
);

# could insist that taxa are NCBI taxa id...

CREATE TABLE taxa (
  taxa_id   int(10) unsigned NOT NULL,
  species   varchar(255) NOT NULL,
  genus     varchar(255) NOT NULL,
  full_lineage mediumtext NOT NULL,
  common_name varchar(255) NOT NULL
);


# we can be a bioentry without a biosequence, but not visa-versa
# most things are going to be keyed off bioentry_id

# accession is the stable id, display_id is a potentially volatile,
# human readable name.

# we will reuse this table for the DR links. I think this is the
# best thing in the long-run


CREATE TABLE bioentry (
  bioentry_id  int(10) unsigned NOT NULL auto_increment,
  biodatabase_id  int(10),
  display_id   varchar(40) NOT NULL,
  accession    varchar(40) NOT NULL,
  entry_version int(10) NOT NULL, 
  UNIQUE (accession,entry_version),
  KEY (biodatabase_id),
  PRIMARY KEY(bioentry_id)
);

# not all entries have a taxa, but many do.
# one bioentry only has one taxa! (weirdo chimerias are not handled. tough)

CREATE TABLE bioentry_taxa (
  bioentry_id int(10)  NOT NULL,
  taxa_id     int(10)  NOT NULL,
  PRIMARY KEY(bioentry_id)
);

# some bioentries will have a sequence
# biosequence because sequence is sometimes 
# a reserved word

CREATE TABLE biosequence (
  biosequence_id  int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  bioentry_id     int(10),
  seq_version     int(6) NOT NULL,
  biosequence_str mediumtext NOT NULL,
  UNIQUE (bioentry_id)
);


#
# Direct links. It is tempting to do this
# from primary_id to primary_id. But that wont work
# during updates of one database - we will have to edit
# this table each time. Better to do the join through accession
# and db each time. Should be almost as cheap



CREATE TABLE bioentry_direct_links (
       source_bioentry_id      int(10) NOT NULL,
       dbname                  varchar(40) NOT NULL,
       accession               varchar(40) NOT NULL,
       PRIMARY KEY (source_bioentry_id)
);


# We can have multiple comments per seqentry, and
# comments can have embedded '\n' characters

CREATE TABLE comment (
  comment_id  int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  bioentry_id    int(10) NOT NULL,
  text           mediumtext NOT NULL
);

# separate description table separate to save on space when we
# don't store descriptions

CREATE TABLE bioentry_description (
   bioentry_id   int(10) unsigned NOT NULL,
   description   varchar(255) NOT NULL,
   PRIMARY KEY(bioentry_id)
);



# references are left to a future implementor to handle.

# features are left out at the moment.
