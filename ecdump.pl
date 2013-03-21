#
# BEGIN_HEADER - DO NOT EDIT
#
# The contents of this file are subject to the terms
# of the Common Development and Distribution License
# (the "License").  You may not use this file except
# in compliance with the License.
#
# You can obtain a copy of the license at
# https://open-esb.dev.java.net/public/CDDLv1.0.html.
# See the License for the specific language governing
# permissions and limitations under the License.
#
# When distributing Covered Code, include this CDDL
# HEADER in each file and include the License file at
# https://open-esb.dev.java.net/public/CDDLv1.0.html.
# If applicable add the following below this CDDL HEADER,
# with the fields enclosed by brackets "[]" replaced with
# your own identifying information: Portions Copyright
# [year] [name of copyright owner]
#

#
# @(#)ecdump.pl
# Copyright 2013-2013 Russ Tremain. All Rights Reserved.
#
# END_HEADER - DO NOT EDIT
#

{
#
#utils - ecdump utility routines
#

use strict;

package ecdump::utils;
my $pkgname = __PACKAGE__;

#imports:
use Exporter 'import';

#package variables:
#symbols we export by default:
our @EXPORT = qw(ec2scm scm2ec dumpThisObject dumpDbKeys init_utils);

#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);

################################### PACKAGE ####################################

sub init_utils
{
    my ($cfg) = @_;

    $DEBUG   = $cfg->getDebug();
    $DDEBUG  = $cfg->getDDebug();
    $QUIET   = $cfg->getQuiet();
    $VERBOSE = $cfg->getVerbose();
}

sub ec2scm
#map EC entity names to legal scm filenames.
#WARNING:  do not call on a full path name!
#TODO:  decide on translation map, perhaps map unwanted chars to UTF-8?
{
    my ($orig) = @_;
    my ($new) = $orig;

    #delete quotes, etc until I can think of a better idea.  RT 3/8/13
    $new =~ tr|\'\"\*\\||d;

    #we cannot allow slashes - map them to '.', following the java convention:
    $new =~ tr|\/|.|;

    if ($VERBOSE && $new ne $orig) {
        printf STDERR "\tec2scm mapped '$orig' -> '$new'\n", $orig, $new;
    }

    return $new;
}

sub scm2ec
#map scm filenames back to EC entity names.
#there is no backward translation defined as of yet.
#this would only come into play for a "restore" feature.
#RT 3/21/13
{
    my ($name) = @_;

    return $name;
}

sub dumpThisObject
{
    my ($aref) = @_;

    for my $kk (keys %$aref) {
        printf STDERR "DUMP kk='%s' aref{%s}='%s'\n", $kk, $kk, defined($$aref{$kk})? $$aref{$kk} : "UNDEF";
    }
}

sub dumpDbKeys
#dump the name, id pairs commonly used to index a db table
{
    my ($aref) = @_;

    for my $kk (sort keys %$aref) {
        printf STDERR "dbKey{%s}='%s'\n", $kk, $$aref{$kk};
    }
}

1;
} #end of ecdump::utils
{
#
#ecProp - object representing an EC Property
#

use strict;

package ecdump::ecProp;
my $pkgname = __PACKAGE__;

#imports:

#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);
our @ISA = qw(ecdump::ecProjects);

my %IgnorePropSheets = ();

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($pprop, $propertyName, $propertyId) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $pprop->config(),
        'mDebug' => $pprop->getDebug(),
        'mDDebug' => $pprop->getDDebug(),
        'mQuiet' => $pprop->getQuiet(),
        'mVerbose' => $pprop->getVerbose(),
        'mSqlpj' => $pprop->sqlpj(),
        'mRootDir' => undef,
        'mPropertyName' => $propertyName,
        'mPropertyId' => $propertyId,
        'mPropertyContentFname' => $pprop->propertyContentFname(),
        'mKidPropName' => undef,
        'mKidPropSheetId' => undef,
        'mKidPropList' => [],
        'mPropertyContent' => '',
        'mDescription' => '',
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    #set output root for the properties (this will be in parent dir):
    $self->{'mRootDir'} = path::mkpathname($pprop->rootDir(), ec2scm($propertyName));

    #copy IgnorePropSheets from configuraton:
    %IgnorePropSheets = %{$self->config->getIgnorePropertiesHash()};

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecProp.defs
sub loadProp
#load this property.
{
    my ($self) = @_;
    my ($name, $id) = ($self->propertyName(), $self->propertyId());

    printf STDERR "LOADING EC PROPERTY (%s,%s)\n", $name, $id if ($DDEBUG);

    #get my description (method defined in ecProjects):
    $self->fetchDescription('ec_property', $id);

    #get my content:
    $self->fetchPropertyContent($name, $id);

    #if we have kid properties (and we are not a EC snapshoot prop)...
    for my $kidobj ($self->getKidPropList()) {
        ##### recursive call #####
        $kidobj->loadProp();
    }

    return 0;
}

sub dumpProp
#dump this property.
{
    my ($self, $indent) = @_;
    my ($name, $id) = ($self->propertyName(), $self->propertyId());
    my $outroot = $self->rootDir();

    printf STDERR "%sDUMPING EC PROPERTY (%s,%s) -> %s\n", ' 'x$indent, $name, $id, $outroot if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #write my description out:
    $self->dumpDescription();
    $self->dumpPropertyContent();

    #if we have kid properties...
    for my $kidobj ($self->getKidPropList()) {
        ##### recursive call #####
        $kidobj->dumpProp($indent+2);
    }

    return 0;
}

sub dumpPropertyContent
#write the property content to a file called content.
#return 0 if successful
{
    my ($self) = @_;
    my $txt = $self->getPropertyContent();
    my $contentfn = $self->propertyContentFname();

    #don't create empty files:
    return 0 if ($txt eq '');

    my $outroot = $self->rootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, $contentfn));
}

sub addKidProps
#add kid prop objects
#call only if property_sheet_id is non-null.
#returns 0 if successful.
{
    my ($self, $parentSheetId, $parentname, $parentid) = @_;
    my ($sqlpj) = $self->sqlpj();

    #this query can return thousands of rows if we are following generated properties.
    #limit the number of properties we retrieve so we can see if it is a candidate for our exception list.  RT 3/10/13
    my $querylimit = 100;
    my $lbuf = sprintf("select name,id from ec_property where parent_sheet_id=%d limit %d", $parentSheetId, $querylimit);

    printf STDERR "%s: running sql query to get name from ID\n", ::srline() if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect one or more rows containing (name,id) pairs
    } @{$sqlpj->getQueryResult()};

    my $cnt = $#results+1;

    #no results are okay - just means that there are not commands associated with procedure step.
    if ( $cnt == 0 ) {
        printf STDERR "%s:  WARNING:  property sheet '%s'[%s]: expected kids but found none.\n", ::srline(), $parentname, $parentid unless ($QUIET);
        return 0;
    }

    #if count of results is not a multiple of 2 ...
    if ( ($cnt == 0) || (($cnt) % 2) != 0 ) {
        printf STDERR "%s:  ERROR:  query '%s' count of results (%d) is zero or not a multiple of 2 (name,id).\n", ::srline(), $lbuf, $cnt;
        return 1;
    }

    #otherwise, allocate new kid prop for each result:
    my @kidobjs = ();
    for (my $ii=0; $ii < $#results; $ii += 2) {
        #do not add prop if in the ignore list:
        my ($name, $id) = ($results[$ii],$results[$ii+1]);
        if (defined($IgnorePropSheets{$name})) {
            ++$IgnorePropSheets{$name};
        } else {
            push @kidobjs, new ecdump::ecProp($self, $name, $id);
        }
    }

    #add list of kid props to this prop:
    $self->setKidPropList(@kidobjs); 

    return 0;
}

sub fetchPropertyContent
#fetch the property content for a given property id.
#caller must have a setPropertyContent(string) method.
#return 0 if successful
{
    my ($self, $name, $id) = @_;
    my ($sqlpj) = $self->sqlpj();

    #this is a result:
    $self->setPropertyContent('');

    #this query should return only one row:
    my $lbuf = sprintf("select property_type,string,numeric_value,clob_id,property_sheet_id from ec_property where id=%d", $id) ;

    printf STDERR "%s: running sql query to get property content fields\n", ::srline() if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect one row with (property_type,string,numeric_value,clob_id,property_sheet_id)
    } @{$sqlpj->getQueryResult()};

    if ( $#results+1 != 5 ) {
        printf STDERR "%s:  ERROR:  query '%s' returned wrong number of results (%d).\n", ::srline(), $lbuf, $#results+1;
        return 1;
    }

    #map undefined values:
    @results = map {
        defined($_) ? $_ : '';
    } @results;

    my ($property_type, $string, $numeric_value, $clob_id, $property_sheet_id) = @results;

    printf STDERR "%s: (property_type,string,numeric_value,clob_id,property_sheet_id)=(%s)\n", ::srline(), join(',', @results) if ($DDEBUG);

    #Note:  if we have a string and a clob, we prefer the clob, which is the full content

    if ($clob_id ne '') {
        my $clobtxt = '';
        if ($self->fetchClobText(\$clobtxt, $clob_id) != 0) {
            printf STDERR "%s:  ERROR:  failed to fetch property clob='%s' for %s[%s]\n", ::srline(), $clob_id, "ec_property", $id;
            return 1;
        }
        $self->setPropertyContent($clobtxt);
    } elsif ($string ne '') {
        $self->setPropertyContent($string);
    } elsif ($numeric_value ne '') {
        $self->setPropertyContent($numeric_value);
    }

    #now add kid properties for this sheet if we have:
    if ($property_type eq "Sheet" && $property_sheet_id ne '') {
        if ($self->addKidProps($property_sheet_id, $name, $id) != 0) {
            printf STDERR "%s:  ERROR:  failed to add child property for (%s,%s)->%s\n", ::srline(), $self->propertyName, $self->propertyId, $property_sheet_id;
            return 1;
        }

        #othewise addKidProps set us up - successful.
    }

    return 0;
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub propertyName
#return value of mPropertyName
{
    my ($self) = @_;
    return $self->{'mPropertyName'};
}

sub propertyId
#return value of mPropertyId
{
    my ($self) = @_;
    return $self->{'mPropertyId'};
}

sub propertyContentFname
#return value of mPropertyContentFname
{
    my ($self) = @_;
    return $self->{'mPropertyContentFname'};
}

sub getKidPropName
#return value of KidPropName
{
    my ($self) = @_;
    return $self->{'mKidPropName'};
}

sub setKidPropName
#set value of KidPropName and return value.
{
    my ($self, $value) = @_;
    $self->{'mKidPropName'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mKidPropName'};
}

sub getKidPropSheetId
#return value of KidPropSheetId
{
    my ($self) = @_;
    return $self->{'mKidPropSheetId'};
}

sub setKidPropSheetId
#set value of KidPropSheetId and return value.
{
    my ($self, $value) = @_;
    $self->{'mKidPropSheetId'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mKidPropSheetId'};
}

sub getKidPropList
#return list @KidPropList
{
    my ($self) = @_;
    return @{$self->{'mKidPropList'}};
}

sub setKidPropList
#set list address of KidPropList and return list.
{
    my ($self, @value) = @_;
    $self->{'mKidPropList'} = \@value;
    $self->update_static_class_attributes();
    return @{$self->{'mKidPropList'}};
}

sub pushKidPropList
#push new values on to KidPropList list and return list.
{
    my ($self, @values) = @_;
    push @{$self->{'mKidPropList'}}, @values;
    return @{$self->{'mKidPropList'}};
}

sub getPropertyContent
#return value of PropertyContent
{
    my ($self) = @_;
    return $self->{'mPropertyContent'};
}

sub setPropertyContent
#set value of PropertyContent and return value.
{
    my ($self, $value) = @_;
    $self->{'mPropertyContent'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mPropertyContent'};
}

sub getDescription
#return value of Description
{
    my ($self) = @_;
    return $self->{'mDescription'};
}

sub setDescription
#set value of Description and return value.
{
    my ($self, $value) = @_;
    $self->{'mDescription'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDescription'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProp
{
#
#ecProps - collection of EC Properties
#

use strict;

package ecdump::ecProps;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";


#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);
our @ISA = qw(ecdump::ecProjects);

my %IgnorePropSheets = ();

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($parent, $parentPropertySheetId, $propertiesDirName, $propertyContentFname) = @_;
    $propertiesDirName = "properties" unless(defined($propertiesDirName));
    $propertyContentFname = "value" unless(defined($propertyContentFname));

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $parent->config(),
        'mDebug' => $parent->getDebug(),
        'mDDebug' => $parent->getDDebug(),
        'mQuiet' => $parent->getQuiet(),
        'mVerbose' => $parent->getVerbose(),
        'mSqlpj' => $parent->sqlpj(),
        'mRootDir' => undef,
        'mParentPropertySheetId' => $parentPropertySheetId,
        'mPropertiesDirName' => $propertiesDirName,
        'mPropertyContentFname' => $propertyContentFname,
        'mDbKeysInitialized' => 0,
        'mNameIdMap' => undef,
        'mEcPropsList' => [],
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    #set output root for the properties (this will be in parent dir):
    $self->{'mRootDir'} = path::mkpathname($parent->rootDir(), ec2scm($propertiesDirName));

    #copy IgnorePropSheets from configuraton:
    %IgnorePropSheets = %{$self->config->getIgnorePropertiesHash()};

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecProps.defs
sub loadProps
#load each EC property from the database
#return 0 on success.
{
    my ($self) = @_;

    #first load myself the Property collection:
    printf STDERR "      LOADING PROPERTIES\n" if ($DDEBUG);
    $self->addAllProps();

    #then load each property:
    for my $proc ($self->ecPropsList()) {
        $proc->loadProp();
    }

    return 0;
}

sub dumpProps
#dump each EC property to the dump tree.
#return 0 on success.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    #first dump myself the Property collection:
    printf STDERR "%sDUMPING PROPERTIES -> %s\n", ' 'x$indent, $outroot if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #then dump each property:
    my $errs = 0;
    for my $prop ($self->ecPropsList()) {
        $errs += $prop->dumpProp($indent+2);
    }

    return $errs;
}

sub loadActualParameters
#alias for loadProp
{
    my ($self) = @_;
    return $self->loadProps(@_);
}

sub dumpActualParameters
#alias for dumpProps
{
    my ($self) = @_;
    return $self->dumpProps(@_);
}

sub addOneProp
#supports list and dump commands.
#add a single property to the collection.
#does not fully populate sub-objects. for that, use loadProps();
#return 0 on success.
{
    my ($self, $propertyName) = @_;

    #initialize property keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initPropKeys());

    #check that we have a legitimate property name:
    if (!defined($self->getNameIdMap->{$propertyName})) {
        printf STDERR "%s:  ERROR:  property '%s' is not in the database.\n", ::srline(), $propertyName;
        return 1;
    }

    #no setter, for mEcPropsList - so use direct ref:
    push @{$self->{'mEcPropsList'}}, (new ecdump::ecProp($self, $propertyName, $self->getNameIdMap->{$propertyName}));


    #TODO:  add property-level properties

    return 0;
}

sub addAllProps
#add all of the EC properties to the collection.
#returns 0 on success
{
    my ($self) = @_;

    #initialize property keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initPropKeys());

    #make sure we start with a clean list, in the event this routine has already been called:
    $self->{'mEcPropsList'} = [];

    #now add one property obj. per retrieved property:
    for my $name (sort keys %{$self->getNameIdMap()}) {
        if (defined($IgnorePropSheets{$name})) {
            ++$IgnorePropSheets{$name};
        } else {
            $self->addOneProp($name);
        }
    }

    return 0;
}

sub initPropKeys
{
    my ($self) = @_;
    my ($sqlpj) = $self->sqlpj();

    #result hash:
    my %nameId = ();
    $self->setNameIdMap(\%nameId);

    #okay if no property sheet is null, I guess...
    return 0 unless ($self->parentPropertySheetId());

    my $lbuf = sprintf("select name,id from ec_property where parent_sheet_id=%s", $self->parentPropertySheetId());

    printf STDERR "%s: running sql query to get properties for parent (%s,%s)\n", ::srline(), $self->rootDir(), $self->parentPropertySheetId  if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect an even number of name,id pairs
    } @{$sqlpj->getQueryResult()};


    #map name,id rows into hash:
    %nameId = @results;

    if ($DDEBUG) {
        printf STDERR "%s: nameId result=\n", ::srline();
        dumpDbKeys(\%nameId);
    }

    $self->setDbKeysInitialized(1);
    return 0;
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub parentPropertySheetId
#return value of mParentPropertySheetId
{
    my ($self) = @_;
    return $self->{'mParentPropertySheetId'};
}

sub propertiesDirName
#return value of mPropertiesDirName
{
    my ($self) = @_;
    return $self->{'mPropertiesDirName'};
}

sub propertyContentFname
#return value of mPropertyContentFname
{
    my ($self) = @_;
    return $self->{'mPropertyContentFname'};
}

sub getDbKeysInitialized
#return value of DbKeysInitialized
{
    my ($self) = @_;
    return $self->{'mDbKeysInitialized'};
}

sub setDbKeysInitialized
#set value of DbKeysInitialized and return value.
{
    my ($self, $value) = @_;
    $self->{'mDbKeysInitialized'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDbKeysInitialized'};
}

sub getNameIdMap
#return value of NameIdMap
{
    my ($self) = @_;
    return $self->{'mNameIdMap'};
}

sub setNameIdMap
#set value of NameIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNameIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNameIdMap'};
}

sub ecPropsList
#return mEcPropsList list
{
    my ($self) = @_;
    return @{$self->{'mEcPropsList'}};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProps
{
#
#ecParameter - object representing a single EC Parameter
#

use strict;

package ecdump::ecParameter;
my $pkgname = __PACKAGE__;

#imports:

#package variables:
ecdump::utils->import;
our @ISA = qw(ecdump::ecProjects);

#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg, $parameterName, $parameterId) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpj' => $cfg->sqlpj(),
        'mRootDir' => undef,
        'mParameterName' => $parameterName,
        'mParameterId' => $parameterId,
        'mParameterContent' => '',
        'mPropertyContentFname' => 'defaultvalue',
        'mSwitchText' => '',
        'mSwitchTextFname' => 'parameter.settings',
        'mDescription' => '',
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #set output root for the properties (this will be in parent dir):
    $self->{'mRootDir'} = path::mkpathname($cfg->rootDir(), ec2scm($self->parameterName()));

    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecParameter.defs
sub loadParameter
#load this parameter.
{
    my ($self) = @_;
    my ($name, $id) = ($self->parameterName(), $self->parameterId());

    printf STDERR "LOADING EC PARAMETER (%s,%s)\n", $name, $id if ($DDEBUG);

    #get my description (method defined in ecProjects):
    $self->fetchDescription('ec_formal_parameter', $id);

    #get my content:
    $self->fetchParameterContent($name, $id);

    return 0;
}

sub dumpParameter
#dump this parameter.
{
    my ($self, $indent) = @_;
    my ($name, $id) = ($self->parameterName(), $self->parameterId());
    my $outroot = $self->rootDir();

    printf STDERR "%sDUMPING EC PARAMETER (%s,%s) -> %s\n", ' 'x$indent, $name, $id, $outroot if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #write my description out:
    $self->dumpDescription();
    $self->dumpParameterContent();
    $self->dumpParameterSwitches();

    return 0;
}

sub dumpParameterSwitches
#write the misc. parameter properties
#return 0 if successful
{
    my ($self) = @_;
    my $txt = $self->getSwitchText();
    my $contentfn = $self->switchTextFname();

    #don't create empty files:
    return 0 if ($txt eq '');

    my $outroot = $self->rootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, $contentfn));
}

sub dumpParameterContent
#write the parameter content to a file called content.
#return 0 if successful
{
    my ($self) = @_;
    my $txt = $self->getParameterContent();
    my $contentfn = $self->propertyContentFname();

    #don't create empty files:
    return 0 if ($txt eq '');

    my $outroot = $self->rootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, $contentfn));
}

sub fetchParameterContent
#fetch the parameter content for a given parameter id.
#caller must have a setParameterContent(string) method.
#return 0 if successful
{
    my ($self, $name, $id) = @_;
    my ($sqlpj) = $self->sqlpj();

    #this is a result:
    $self->setParameterContent('');

# ec_formal_parameter:(id, version, name, created, created_millis, deleted, last_modified_by, modified, modified_millis, owner, default_value, description, entity_id, entity_type, expansion_deferred, required, type, acl_id, default_value_clob_id, description_clob_id)

    #this query should return only one row:
    my $lbuf = sprintf("select type, expansion_deferred, required, acl_id, default_value_clob_id, default_value from ec_formal_parameter where id=%d", $id);

    printf STDERR "%s: running sql query to get parameter content fields\n", ::srline() if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect one row with (type, expansion_deferred, required, acl_id, default_value_clob_id, default_value)
    } @{$sqlpj->getQueryResult()};

    if ( $#results+1 != 6 ) {
        printf STDERR "%s:  ERROR:  query '%s' returned wrong number of results (%d).\n", ::srline(), $lbuf, $#results+1;
        return 1;
    }

    #map undefined values:
    @results = map {
        defined($_) ? $_ : '';
    } @results;

    my ($type, $expansion_deferred, $required, $acl_id, $default_value_clob_id, $default_value) = @results;

    #$self->setDDebug(1);
    printf STDERR "%s: (type, expansion_deferred, required, acl_id, default_value_clob_id, default_value)=(%s)\n", ::srline(), join(',', @results) if ($DDEBUG);
    #$self->setDDebug(0);

    #create switches text (in a form that can be consumed by a posix shell):
    my $switches=sprintf("parameter_type='%s'
parameter_expansion_deferred='%s'
parameter_required='%s'
", $type, $expansion_deferred, $required);

    $self->setSwitchText($switches);

    #Note:  if we have a string and a clob, we prefer the clob, which is the full content

    if ($default_value_clob_id ne '') {
        my $clobtxt = '';
        if ($self->fetchClobText(\$clobtxt, $default_value_clob_id) != 0) {
            printf STDERR "%s:  ERROR:  failed to fetch parameter clob='%s' for %s[%s]\n", ::srline(), $default_value_clob_id, "ec_formal_parameter", $id;
            return 1;
        }
        $self->setParameterContent($clobtxt);
    } elsif ($default_value ne '') {
        $self->setParameterContent($default_value);
    }

    return 0;
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub parameterName
#return value of mParameterName
{
    my ($self) = @_;
    return $self->{'mParameterName'};
}

sub parameterId
#return value of mParameterId
{
    my ($self) = @_;
    return $self->{'mParameterId'};
}

sub getParameterContent
#return value of ParameterContent
{
    my ($self) = @_;
    return $self->{'mParameterContent'};
}

sub setParameterContent
#set value of ParameterContent and return value.
{
    my ($self, $value) = @_;
    $self->{'mParameterContent'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mParameterContent'};
}

sub propertyContentFname
#return value of mPropertyContentFname
{
    my ($self) = @_;
    return $self->{'mPropertyContentFname'};
}

sub getSwitchText
#return value of SwitchText
{
    my ($self) = @_;
    return $self->{'mSwitchText'};
}

sub setSwitchText
#set value of SwitchText and return value.
{
    my ($self, $value) = @_;
    $self->{'mSwitchText'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mSwitchText'};
}

sub switchTextFname
#return value of mSwitchTextFname
{
    my ($self) = @_;
    return $self->{'mSwitchTextFname'};
}

sub getDescription
#return value of Description
{
    my ($self) = @_;
    return $self->{'mDescription'};
}

sub setDescription
#set value of Description and return value.
{
    my ($self, $value) = @_;
    $self->{'mDescription'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDescription'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecParameter
{
#
#ecParameters - collection of EC Parameters
#

use strict;

package ecdump::ecParameters;
my $pkgname = __PACKAGE__;

#imports:

#package variables:
ecdump::utils->import;
our @ISA = qw(ecdump::ecProjects);

#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg, $parentName, $parentId, $parentParameterTable, $parentParameterTableIdColumn) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpj' => $cfg->sqlpj(),
        'mRootDir' => undef,
        'mParameterTable' => $parentParameterTable,
        'mParameterTableIdColumn' => $parentParameterTableIdColumn,
        'mParentEntityId' => $parentId,
        'mParentEntityName' => $parentName,
        'mDbKeysInitialized' => 0,
        'mNameIdMap' => undef,
        'mEcParameterList' => [],
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #set output root for the properties (this will be in parent dir):
    $self->{'mRootDir'} = path::mkpathname($cfg->rootDir(), ec2scm('parameters'));

    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecParameters.defs
sub loadParameters
#load each EC parameter from the database
#return 0 on success.
{
    my ($self) = @_;

    #first load myself the Parameter collection:
    printf STDERR "      LOADING PARAMETERS\n" if ($DDEBUG);
    $self->addAllParameters();

    #then load each parameter:
    for my $proc ($self->ecParameterList()) {
        $proc->loadParameter();
    }

    return 0;
}

sub dumpParameters
#dump each EC parameter to the dump tree.
#return 0 on success.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    #first dump myself the Parameter collection:
    printf STDERR "%sDUMPING PARAMETERS -> %s\n", ' 'x$indent, $outroot if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #then dump each parameter:
    my $errs = 0;
    for my $param ($self->ecParameterList()) {
        $errs += $param->dumpParameter($indent+2);
    }

    return $errs;
}

sub addOneParameter
#supports list and dump commands.
#add a single parameter to the collection.
#does not fully populate sub-objects. for that, use loadParameters();
#return 0 on success.
{
    my ($self, $parameterName) = @_;

    #initialize parameter keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initParameterKeys());

    #check that we have a legitimate parameter name:
    if (!defined($self->getNameIdMap->{$parameterName})) {
        printf STDERR "%s:  ERROR:  parameter '%s' is not in the database.\n", ::srline(), $parameterName;
        return 1;
    }

    #no setter, for mEcParameterList - so use direct ref:
    push @{$self->{'mEcParameterList'}}, (new ecdump::ecParameter($self, $parameterName, $self->getNameIdMap->{$parameterName}));

    return 0;
}

sub addAllParameters
#add all of the EC parameters to the collection.
#returns 0 on success
{
    my ($self) = @_;

    #initialize parameter keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initParameterKeys());

    #make sure we start with a clean list, in the event this routine has already been called:
    $self->{'mEcParameterList'} = [];

    #now add one parameter obj. per retrieved parameter:
    for my $name (sort keys %{$self->getNameIdMap()}) {
        $self->addOneParameter($name);
    }

    return 0;
}

sub initParameterKeys
#create a table mapping ec_formal_parameter:(name,id) pairs to parent entity.
#similar to EcProps except for differing linking tables names for different parent entities.
{
    my ($self) = @_;
    my ($sqlpj) = $self->sqlpj();

    #result hash:
    my %nameId = ();
    $self->setNameIdMap(\%nameId);

    #okay if no parameter sheet is null, I guess...
    return 0 unless ($self->parentEntityId());

# ec_formal_parameter:(id, version, name, created, created_millis, deleted, last_modified_by, modified, modified_millis, owner, default_value, description, entity_id, entity_type, expansion_deferred, required, type, acl_id, default_value_clob_id, description_clob_id)
# ec_procedure_formal_parameter:(procedure_id, formal_parameter_id)
# ec_procedure:(id, name, description, job_name_template, resource_name, workspace_name, acl_id, property_sheet_id, description_clob_id, job_name_template_clob_id, project_id)
# select R.id, R.name, R.project_id, J.name, F.id, F.name, F.default_value, F.description, F.type, F.required, F.expansion_deferred
#     from ec_procedure R, ec_project J, ec_procedure_formal_parameter M, ec_formal_parameter F
#     where R.name='Module.CollectSources'and R.project_id = 399 and R.project_id = J.id
#          and F.id = M.formal_parameter_id and M.procedure_id = R.id

    my $lbuf = sprintf("select F.name, F.id
            from ec_formal_parameter F, %s M
            where F.id = M.formal_parameter_id and M.%s = %s",
        $self->parameterTable,
        $self->parameterTableIdColumn,
        $self->parentEntityId());

    printf STDERR "%s: running sql query to get parameters for parent (%s,%s)\n", ::srline(), $self->rootDir(), $self->parentEntityName  if ($DDEBUG);
    printf STDERR "%s: sql query='%s'\n", ::srline(), $lbuf  if ($DDEBUG);

    #note zero results is okay - just means parent entity has no parameters.
    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect an even number of name,id pairs
    } @{$sqlpj->getQueryResult()};


    #map name,id rows into hash:
    %nameId = @results;

    if ($DEBUG) {
        printf STDERR "%s: nameId result=\n", ::srline();
        dumpDbKeys(\%nameId);
    }

    $self->setDbKeysInitialized(1);
    return 0;
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub parameterTable
#return value of mParameterTable
{
    my ($self) = @_;
    return $self->{'mParameterTable'};
}

sub parameterTableIdColumn
#return value of mParameterTableIdColumn
{
    my ($self) = @_;
    return $self->{'mParameterTableIdColumn'};
}

sub parentEntityId
#return value of mParentEntityId
{
    my ($self) = @_;
    return $self->{'mParentEntityId'};
}

sub parentEntityName
#return value of mParentEntityName
{
    my ($self) = @_;
    return $self->{'mParentEntityName'};
}

sub getDbKeysInitialized
#return value of DbKeysInitialized
{
    my ($self) = @_;
    return $self->{'mDbKeysInitialized'};
}

sub setDbKeysInitialized
#set value of DbKeysInitialized and return value.
{
    my ($self, $value) = @_;
    $self->{'mDbKeysInitialized'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDbKeysInitialized'};
}

sub getNameIdMap
#return value of NameIdMap
{
    my ($self) = @_;
    return $self->{'mNameIdMap'};
}

sub setNameIdMap
#set value of NameIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNameIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNameIdMap'};
}

sub ecParameterList
#return mEcParameterList list
{
    my ($self) = @_;
    return @{$self->{'mEcParameterList'}};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecParameters
{
#
#ecProcedureStep - object representing an EC Procedure Step
#

use strict;

package ecdump::ecProcedureStep;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";


#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);
our @ISA = qw(ecdump::ecProjects);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg, $procedureStepName, $procedureStepId, $propertySheetId, $actualParametersId) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $cfg->config(),
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpj' => $cfg->sqlpj(),
        'mIndexProcedureStepNames' => $cfg->config->getIndexProcedureStepNameOption(),
        'mRootDir' => $cfg->rootDir(),
        'mProcedureStepName' => $procedureStepName,
        'mProcedureStepId' => $procedureStepId,
        'mProcStepCommand' => '',
        'mProcStepPostProcessor' => '',
        'mProcStepIndex' => -1,
        'mProcStepSubprocedure' => '',
        'mProcStepSubproject' => '',
        'mSwitchText' => '',
        'mSwitchTextFname' => 'procstep.settings',
        'mDescription' => '',
        'mPropertySheetId' => $propertySheetId,
        'mActualParametersId' => $actualParametersId,
        'mEcProps' => undef,
        'mEcParameters' => undef,
        'mEcActualParameters' => undef,
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecProcedureStep.defs
sub loadProcedureStep
#load this procedure step.
{
    my ($self) = @_;
    my($name, $id) = ($self->procedureStepName(), $self->procedureStepId());
    my $outroot = $self->getRootDir();
    my $addStepIndex = $self->indexProcedureStepNames();

    #first load this Procedure Step:
    printf STDERR "LOADING PROCEDURE STEP (%s,%s)\n", $name, $id  if ($DDEBUG);

    #get my description (method defined in ecProjects):
    $self->fetchDescription('ec_procedure_step', $id);

    #get my content:
    $self->fetchProcStepContent($name, $id);

    #this is not valid until the fetch:
    my $step_index = $self->getProcStepIndex();

    #now we can finally set RootDir:
    if ($addStepIndex) {
        $self->setRootDir(path::mkpathname($outroot, sprintf("%02d_%s", $step_index, ec2scm($name))));
    } else {
        $self->setRootDir(path::mkpathname($outroot, ec2scm($name)));
    }

    #$self->setDDebug(1);
    printf STDERR "%s: outroot:  '%s'->'%s'\n", ::srline(), $outroot, $self->getRootDir() if ($DDEBUG);
    #$self->setDDebug(0);


    #### we had to delay creating our sub-objects until root was set. ###
    my ($psid, $apid) = ($self->propertySheetId(), $self->actualParametersId());

    #create properties container object, which will contain the list of our properties:
    $self->{'mEcProps'} = new ecdump::ecProps($self, $psid);

    #create parameters container object, which will contain the list of our formal parameters:
    $self->{'mEcParameters'} = new ecdump::ecParameters($self, $name, $id, 'ec_procedure_step_parameter', 'procedure_step_id');

    #create actual parameters container object, which in actuality is a list of properties:
    $self->{'mEcActualParameters'} = new ecdump::ecProps($self, $apid, "actualparameters", "defaultvalue");

    #load my formal parameters (most steps do not have):
    #$self->ecParameters->setDDebug(1);
    $self->ecParameters->loadParameters();
    #$self->ecParameters->setDDebug(0);

    #load my actual parameters:
    $self->ecActualParameters->loadActualParameters();

    #load my properties:
    $self->ecProps->loadProps();

    return 0;
}

sub dumpProcedureStep
#dump this procedure step.
#return 0 on success
{
    my ($self, $indent) = @_;
    my $outroot = $self->getRootDir();

    #first dump this Procedure Step:
    printf STDERR "%sDUMPING PROCEDURE STEP (%s,%s) -> %s\n", ' 'x$indent, $self->procedureStepName, $self->procedureStepId, $outroot   if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #write my description out:
    $self->dumpDescription();

    #write my content out:
    $self->dumpProcStepContent();

    #dump my formal parameters: 
    #skip this step for now as these are not really used.  RT 3/19/13
    #$self->ecParameters->dumpParameters($indent+2);

    #dump my actual parameters:
    $self->ecActualParameters->dumpActualParameters();

    #dump my properties:
    $self->ecProps->dumpProps($indent+2);

    return 0;
}

sub dumpProcStepContent
#write the property content to a file called content.
#return 0 if successful
{
    my ($self) = @_;
    my ($errs) = 0;

    $errs += $self->dumpProcStepCommand();
    $errs += $self->dumpProcStepPostProcessor();
    $errs += $self->dumpProcStepSubprocedure();
    $errs += $self->dumpProcStepSwitches();

    return $errs;
}

sub dumpProcStepCommand
#write the proc step command to a file called command
#return 0 if successful
{
    my ($self) = @_;
    my $txt = $self->getProcStepCommand();

    #don't create empty files:
    return 0 if ($txt eq '');

    my $outroot = $self->getRootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, "command"));
}

sub dumpProcStepPostProcessor
#write the proc step command to a file called command
#return 0 if successful
{
    my ($self) = @_;
    my $txt = $self->getProcStepPostProcessor();

    #don't create empty files:
    return 0 if ($txt eq '');

    my $outroot = $self->getRootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, "postprocessor"));
}

sub dumpProcStepSubprocedure
#write the subprocedure call to a file called subprocedure
#return 0 if successful
{
    my ($self) = @_;
    my $subprocedure = $self->getProcStepSubprocedure();
    my $subproject   = $self->getProcStepSubproject();
    my $txt = $subprocedure;

    #don't create empty files:
    return 0 if ($txt eq '');

    if ($subprocedure ne '' && $subproject ne '') {
        $txt = sprintf("%s/%s", $subproject, $subprocedure);
    }

    my $outroot = $self->getRootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, "subprocedure"));
}

sub dumpProcStepSwitches
#write the misc. parameter properties
#return 0 if successful
{
    my ($self) = @_;
    my $txt = $self->getSwitchText();
    my $contentfn = $self->switchTextFname();

    #don't create empty files:
    return 0 if ($txt eq '');

    my $outroot = $self->rootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, $contentfn));
}

sub fetchProcStepContent
#fetch the procedure step content for a given procedure step id.
#return 0 if successful
{
    my ($self, $name, $id) = @_;
    my ($sqlpj) = $self->sqlpj();

    #these are results:
    $self->setProcStepCommand('');
    $self->setProcStepPostProcessor('');

    # ec_procedure_step partial schema:
    #(id, name, exclusive_mode, release_mode, always_run, broadcast, command, step_condition,
    # description, post_processor, error_handling, log_file_name, parallel, resource_name,
    # shell, subprocedure, subproject, time_limit, time_limit_units, working_directory, workspace_name,
    # acl_id, property_sheet_id, actual_parameters_id, command_clob_id, step_condition_clob_id,
    # description_clob_id, post_processor_clob_id, procedure_id, step_index)

    #this query should return only one row:
    my $lbuf = sprintf("select
        step_index,
        subprocedure,
        subproject,
        acl_id,
        always_run,
        broadcast,
        error_handling,
        exclusive_mode,
        log_file_name,
        parallel,
        release_mode,
        resource_name,
        shell,
        time_limit,
        time_limit_units,
        working_directory,
        workspace_name,
        command_clob_id,
        post_processor_clob_id,
        step_condition_clob_id,
        post_processor,
        step_condition,
        command
from ec_procedure_step
where id=%d", $id);

    printf STDERR "%s: running sql query to get procedure step content fields\n", ::srline() if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect one row
    } @{$sqlpj->getQueryResult()};

    if ( $#results+1 != 23 ) {
        printf STDERR "%s:  ERROR:  query '%s' returned wrong number of results (%d).\n", ::srline(), $lbuf, $#results+1;
        return 1;
    }

    #map undefined values:
    @results = map {
        defined($_) ? $_ : '';
    } @results;

    my ($step_index,
        $subprocedure,
        $subproject,
        $acl_id,
        $always_run,
        $broadcast,
        $error_handling,
        $exclusive_mode,
        $log_file_name,
        $parallel,
        $release_mode,
        $resource_name,
        $shell,
        $time_limit,
        $time_limit_units,
        $working_directory,
        $workspace_name,
        $command_clob_id,
        $post_processor_clob_id,
        $step_condition_clob_id,
        $post_processor,
        $step_condition,
        $command) = @results;

    #$self->setDDebug(1);
    printf STDERR "%s: (step_index,subprocedure,subproject,acl_id,always_run,broadcast,error_handling,exclusive_mode,log_file_name,parallel,release_mode,resource_name,shell,time_limit,time_limit_units,working_directory,workspace_name,command_clob_id,post_processor_clob_id,step_condition_clob_id,post_processor,step_condition,command)=(%s)\n",
        ::srline(), join(',', ($name,$id,@results)) if ($DDEBUG);
    #$self->setDDebug(0);

    #Note:  if we have a string and a clob, we prefer the clob, which is the full content

    if ($command_clob_id ne '') {
        my $clobtxt = '';
        if ($self->fetchClobText(\$clobtxt, $command_clob_id) != 0) {
            printf STDERR "%s:  ERROR:  failed to fetch command_clob='%s' for %s[%s]\n", ::srline(), $command_clob_id, "ec_procedure step", $id;
            return 1;
        }
        $self->setProcStepCommand($clobtxt);
    } elsif ($command ne '') {
        $self->setProcStepCommand($command);
    }

    #now set postprocessor text if it exists:
    if ($post_processor_clob_id ne '') {
        my $clobtxt = '';
        if ($self->fetchClobText(\$clobtxt, $post_processor_clob_id) != 0) {
            printf STDERR "%s:  ERROR:  failed to fetch post_processor_clob='%s' for %s[%s]\n", ::srline(), $post_processor_clob_id, "ec_procedure step", $id;
            return 1;
        }
        $self->setProcStepPostProcessor($clobtxt);
    } elsif ($post_processor ne '') {
        $self->setProcStepPostProcessor($post_processor);
    }

    #set subprocedure, subproject:
    $self->setProcStepSubprocedure($subprocedure);
    $self->setProcStepSubproject($subproject);

    #set step index for procedure step:
    $self->setProcStepIndex($step_index);

    #create switches text (in a form that can be consumed by a posix shell):
    my $switches=sprintf("procstep_always_run='%s'
procstep_broadcast='%s'
procstep_error_handling='%s'
procstep_exclusive_mode='%s'
procstep_log_file_name='%s'
procstep_parallel='%s'
procstep_release_mode='%s'
procstep_resource_name='%s'
procstep_shell='%s'
procstep_step_index='%s'
procstep_time_limit='%s'
procstep_time_limit_units='%s'
procstep_working_directory='%s'
procstep_workspace_name='%s'
", $always_run, $broadcast, $error_handling, $exclusive_mode, $log_file_name,
    $parallel, $release_mode, $resource_name, $shell, $step_index, $time_limit, $time_limit_units,
    $working_directory, $workspace_name);

    $self->setSwitchText($switches);

    return 0;
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub indexProcedureStepNames
#return value of mIndexProcedureStepNames
{
    my ($self) = @_;
    return $self->{'mIndexProcedureStepNames'};
}

sub getRootDir
#return value of RootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub setRootDir
#set value of RootDir and return value.
{
    my ($self, $value) = @_;
    $self->{'mRootDir'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mRootDir'};
}

sub procedureStepName
#return value of mProcedureStepName
{
    my ($self) = @_;
    return $self->{'mProcedureStepName'};
}

sub procedureStepId
#return value of mProcedureStepId
{
    my ($self) = @_;
    return $self->{'mProcedureStepId'};
}

sub getProcStepCommand
#return value of ProcStepCommand
{
    my ($self) = @_;
    return $self->{'mProcStepCommand'};
}

sub setProcStepCommand
#set value of ProcStepCommand and return value.
{
    my ($self, $value) = @_;
    $self->{'mProcStepCommand'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mProcStepCommand'};
}

sub getProcStepPostProcessor
#return value of ProcStepPostProcessor
{
    my ($self) = @_;
    return $self->{'mProcStepPostProcessor'};
}

sub setProcStepPostProcessor
#set value of ProcStepPostProcessor and return value.
{
    my ($self, $value) = @_;
    $self->{'mProcStepPostProcessor'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mProcStepPostProcessor'};
}

sub getProcStepIndex
#return value of ProcStepIndex
{
    my ($self) = @_;
    return $self->{'mProcStepIndex'};
}

sub setProcStepIndex
#set value of ProcStepIndex and return value.
{
    my ($self, $value) = @_;
    $self->{'mProcStepIndex'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mProcStepIndex'};
}

sub getProcStepSubprocedure
#return value of ProcStepSubprocedure
{
    my ($self) = @_;
    return $self->{'mProcStepSubprocedure'};
}

sub setProcStepSubprocedure
#set value of ProcStepSubprocedure and return value.
{
    my ($self, $value) = @_;
    $self->{'mProcStepSubprocedure'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mProcStepSubprocedure'};
}

sub getProcStepSubproject
#return value of ProcStepSubproject
{
    my ($self) = @_;
    return $self->{'mProcStepSubproject'};
}

sub setProcStepSubproject
#set value of ProcStepSubproject and return value.
{
    my ($self, $value) = @_;
    $self->{'mProcStepSubproject'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mProcStepSubproject'};
}

sub getSwitchText
#return value of SwitchText
{
    my ($self) = @_;
    return $self->{'mSwitchText'};
}

sub setSwitchText
#set value of SwitchText and return value.
{
    my ($self, $value) = @_;
    $self->{'mSwitchText'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mSwitchText'};
}

sub switchTextFname
#return value of mSwitchTextFname
{
    my ($self) = @_;
    return $self->{'mSwitchTextFname'};
}

sub getDescription
#return value of Description
{
    my ($self) = @_;
    return $self->{'mDescription'};
}

sub setDescription
#set value of Description and return value.
{
    my ($self, $value) = @_;
    $self->{'mDescription'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDescription'};
}

sub propertySheetId
#return value of mPropertySheetId
{
    my ($self) = @_;
    return $self->{'mPropertySheetId'};
}

sub actualParametersId
#return value of mActualParametersId
{
    my ($self) = @_;
    return $self->{'mActualParametersId'};
}

sub ecProps
#return value of mEcProps
{
    my ($self) = @_;
    return $self->{'mEcProps'};
}

sub ecParameters
#return value of mEcParameters
{
    my ($self) = @_;
    return $self->{'mEcParameters'};
}

sub ecActualParameters
#return value of mEcActualParameters
{
    my ($self) = @_;
    return $self->{'mEcActualParameters'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProcedureStep
{
#
#ecProcedureSteps - collection of Procedure Steps
#

use strict;

package ecdump::ecProcedureSteps;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";


#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);
our @ISA = qw(ecdump::ecProjects);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $cfg->config(),
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpj' => $cfg->sqlpj(),
        'mRootDir' => undef,
        'mProcedureName' => $cfg->procedureName,
        'mProcedureId' => $cfg->procedureId,
        'mDbKeysInitialized' => 0,
        'mNameIdMap' => undef,
        'mNamePropIdMap' => undef,
        'mNameActualParamsIdMap' => undef,
        'mEcProcedureStepsList' => [],
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    #set output root for this the procedures:
    $self->{'mRootDir'} = path::mkpathname($cfg->rootDir(), ec2scm("proceduresteps"));

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecProcedureSteps.defs
sub loadProcedureSteps
#load each EC procedure step from the database
#return 0 on success.
{
    my ($self) = @_;

    #first load myself the Procedure Step collection:
    printf STDERR "      LOADING PROCEDURE Steps\n" if ($DDEBUG);
    $self->addAllProcedureSteps();

    #then load each procedures step:
    for my $proc ($self->ecProcedureStepsList()) {
        $proc->loadProcedureStep();
    }

    return 0;
}

sub dumpProcedureSteps
#dump each EC procedure step to the dump tree.
#return 0 on success.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    #first dump myself the Procedure Step collection:
    printf STDERR "%sDUMPING PROCEDURE Steps -> %s\n", ' 'x$indent, $outroot if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #then dump each procedures step:
    my $errs = 0;
    for my $proc ($self->ecProcedureStepsList()) {
        $errs += $proc->dumpProcedureStep($indent+2);
    }

    return $errs;
}

sub addOneProcedureStep
#supports list and dump commands.
#add a single procedureStep to the collection.
#does not fully populate sub-objects. for that, use loadProcedureSteps();
#return 0 on success.
{
    my ($self, $procedureStepName) = @_;

    #initialize procedureStep keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initProcedureStepKeys());

    #check that we have a legitimate procedureStep name:
    if (!defined($self->getNameIdMap->{$procedureStepName})) {
        printf STDERR "%s:  ERROR:  procedureStep '%s' is not in the database.\n", ::srline(), $procedureStepName;
        return 1;
    }

    #no setter, for mEcProcedureStepsList - so use direct ref:
    push @{$self->{'mEcProcedureStepsList'}},
        (new ecdump::ecProcedureStep($self,
            $procedureStepName,
            $self->getNameIdMap->{$procedureStepName},
            $self->getNamePropIdMap->{$procedureStepName},
            $self->getNameActualParamsIdMap->{$procedureStepName}));

    return 0;
}

sub addAllProcedureSteps
#add all of the EC procedureSteps to the collection.
#returns 0 on success
{
    my ($self) = @_;

    #initialize procedureStep keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initProcedureStepKeys());

    #make sure we start with a clean list, in the event this routine has already been called:
    $self->{'mEcProcedureStepsList'} = [];

    #now add one procedureStep obj. per retrieved procedureStep:
    for my $name (sort keys %{$self->getNameIdMap()}) {
        $self->addOneProcedureStep($name);
    }

    return 0;
}

sub initProcedureStepKeys
{
    my ($self) = @_;
    my ($sqlpj) = $self->sqlpj();

    my $lbuf = sprintf("select name,id,property_sheet_id,actual_parameters_id from ec_procedure_step where procedure_id=%s", $self->procedureId);

    printf STDERR "%s: running sql query to get procedureSteps for procedure (%s,%s)\n", ::srline(), $self->procedureName, $self->procedureId  if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.
    } @{$sqlpj->getQueryResult()};

    #map (name,id,propert_sheet_id,actual_parameters_id) tuples into hashes:
    my (%nameId, %namePropId, %nameActualParamsId);
    for (my $ii=0; $ii < $#results; $ii += 4) {
        $nameId{$results[$ii]} = $results[$ii+1];
        $namePropId{$results[$ii]} = $results[$ii+2];
        $nameActualParamsId{$results[$ii]} = $results[$ii+3];
    }
    
    $self->setNameIdMap(\%nameId);
    $self->setNamePropIdMap(\%namePropId);
    $self->setNameActualParamsIdMap(\%nameActualParamsId);

    if ($DDEBUG) {
        printf STDERR "%s: nameId result=\n", ::srline();
        dumpDbKeys(\%nameId);

        printf STDERR "%s: namePropId result=\n", ::srline();
        dumpDbKeys(\%namePropId);

        printf STDERR "%s: nameActualParamsId result=\n", ::srline();
        dumpDbKeys(\%nameActualParamsId);
    }

    $self->setDbKeysInitialized(1);
    return 0;
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub procedureName
#return value of mProcedureName
{
    my ($self) = @_;
    return $self->{'mProcedureName'};
}

sub procedureId
#return value of mProcedureId
{
    my ($self) = @_;
    return $self->{'mProcedureId'};
}

sub getDbKeysInitialized
#return value of DbKeysInitialized
{
    my ($self) = @_;
    return $self->{'mDbKeysInitialized'};
}

sub setDbKeysInitialized
#set value of DbKeysInitialized and return value.
{
    my ($self, $value) = @_;
    $self->{'mDbKeysInitialized'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDbKeysInitialized'};
}

sub getNameIdMap
#return value of NameIdMap
{
    my ($self) = @_;
    return $self->{'mNameIdMap'};
}

sub setNameIdMap
#set value of NameIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNameIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNameIdMap'};
}

sub getNamePropIdMap
#return value of NamePropIdMap
{
    my ($self) = @_;
    return $self->{'mNamePropIdMap'};
}

sub setNamePropIdMap
#set value of NamePropIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNamePropIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNamePropIdMap'};
}

sub getNameActualParamsIdMap
#return value of NameActualParamsIdMap
{
    my ($self) = @_;
    return $self->{'mNameActualParamsIdMap'};
}

sub setNameActualParamsIdMap
#set value of NameActualParamsIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNameActualParamsIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNameActualParamsIdMap'};
}

sub ecProcedureStepsList
#return mEcProcedureStepsList list
{
    my ($self) = @_;
    return @{$self->{'mEcProcedureStepsList'}};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProcedureSteps
{
#
#ecProcedure - object representing an EC Procedure
#

use strict;

package ecdump::ecProcedure;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";


#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);
our @ISA = qw(ecdump::ecProjects);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg, $procedureName, $procedureId, $propertySheetId) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $cfg->config(),
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpj' => $cfg->sqlpj(),
        'mRootDir' => undef,
        'mProcedureName' => $procedureName,
        'mProcedureId' => $procedureId,
        'mDescription' => '',
        'mEcProcedureSteps' => undef,
        'mPropertySheetId' => $propertySheetId,
        'mEcProps' => undef,
        'mEcParameters' => undef,
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    #set output root for this the procedures:
    $self->{'mRootDir'} = path::mkpathname($cfg->rootDir(), ec2scm($procedureName));

    #create parameters container object, which will contain the list of our parameters:
    $self->{'mEcParameters'} = new ecdump::ecParameters($self, $procedureName, $procedureId, 'ec_procedure_formal_parameter', 'procedure_id');

    #create properties container object, which will contain the list of our properties:
    $self->{'mEcProps'} = new ecdump::ecProps($self, $propertySheetId);

    #create procedure steps container object, which will contain the list of our procedure steps:
    $self->{'mEcProcedureSteps'} = new ecdump::ecProcedureSteps($self);

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecProcedure.defs
sub loadProcedure
#load this EC procedure from the database.
#return 0 on success.
{
    my ($self) = @_;

    #first load this procedure:
    printf STDERR "    LOADING PROCEDURE (%s,%s)\n", $self->procedureName, $self->procedureId  if ($DDEBUG);

    #get my description (method defined in ecProjects):
    $self->fetchDescription('ec_procedure', $self->procedureId);

    #load my parameters:
    $self->ecParameters->loadParameters();

    #load my properties:
    $self->ecProps->loadProps();

    #then load procedure steps:
    $self->ecProcedureSteps->loadProcedureSteps();

    return 0;
}

sub dumpProcedure
#dump this EC procedure to the dump tree.
#return 0 on success.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    #first dump myself this procedure:
    printf STDERR "%sDUMPING PROCEDURE (%s,%s) -> %s\n", ' 'x$indent, $self->procedureName, $self->procedureId, $outroot  if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #write my description out:
    $self->dumpDescription();

    #dump my parameters:
    $self->ecParameters->dumpParameters($indent+2);

    #dump my properties:
    $self->ecProps->dumpProps($indent+2);

    #then dump procedure steps:
    return $self->ecProcedureSteps->dumpProcedureSteps($indent+2);
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub procedureName
#return value of mProcedureName
{
    my ($self) = @_;
    return $self->{'mProcedureName'};
}

sub procedureId
#return value of mProcedureId
{
    my ($self) = @_;
    return $self->{'mProcedureId'};
}

sub getDescription
#return value of Description
{
    my ($self) = @_;
    return $self->{'mDescription'};
}

sub setDescription
#set value of Description and return value.
{
    my ($self, $value) = @_;
    $self->{'mDescription'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDescription'};
}

sub ecProcedureSteps
#return value of mEcProcedureSteps
{
    my ($self) = @_;
    return $self->{'mEcProcedureSteps'};
}

sub propertySheetId
#return value of mPropertySheetId
{
    my ($self) = @_;
    return $self->{'mPropertySheetId'};
}

sub ecProps
#return value of mEcProps
{
    my ($self) = @_;
    return $self->{'mEcProps'};
}

sub ecParameters
#return value of mEcParameters
{
    my ($self) = @_;
    return $self->{'mEcParameters'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProcedure
{
#
#ecProcedures - collection of EC Procedures
#

use strict;

package ecdump::ecProcedures;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";


#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);
our @ISA = qw(ecdump::ecProjects);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($proj) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $proj->config(),
        'mDebug' => $proj->getDebug(),
        'mDDebug' => $proj->getDDebug(),
        'mQuiet' => $proj->getQuiet(),
        'mVerbose' => $proj->getVerbose(),
        'mSqlpj' => $proj->sqlpj(),
        'mRootDir' => undef,
        'mProjectName' => $proj->projectName(),
        'mProjectId' => $proj->projectId(),
        'mEcProcedureList' => [],
        'mDbKeysInitialized' => 0,
        'mNameIdMap' => undef,
        'mNamePropIdMap' => undef,
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    #set output root for this the procedures:
    $self->{'mRootDir'} = path::mkpathname($proj->rootDir(), ec2scm("procedures"));

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecProcedures.defs
sub loadProcedures
#load each EC procedure from the database
#return 0 on success.
{
    my ($self) = @_;

    #first load myself the Procedure collection:
    printf STDERR "  LOADING PROCEDURES\n" if ($DDEBUG);
    $self->addAllProcedures();

    #then load each procedures:
    for my $proc ($self->ecProcedureList()) {
        $proc->loadProcedure();
    }

    return 0;
}

sub dumpProcedures
#dump each EC procedure to the dump tree.
#return 0 on success.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    #first dump myself the Procedure collection:
    printf STDERR "%sDUMPING PROCEDURES -> %s\n", ' 'x$indent, $outroot if ($DEBUG);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    my $errs = 0;
    #then dump each procedures:
    for my $proc ($self->ecProcedureList()) {
        $errs += $proc->dumpProcedure($indent+2);
    }

    return $errs;
}

sub initProcedureKeys
{
    my ($self) = @_;
    my ($sqlpj) = $self->sqlpj();

    my $lbuf = sprintf("select name,id,property_sheet_id from ec_procedure where project_id=%d", $self->projectId);

    printf STDERR "%s: running sql query to get procedures for project (%s,%d)\n", ::srline(), $self->projectName, $self->projectId  if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect an even number of name,id pairs
    } @{$sqlpj->getQueryResult()};

    #map (name,id,propert_sheet_id) triples into nameId and namePropId hashes:
    my (%nameId, %namePropId);
    for (my $ii=0; $ii < $#results; $ii += 3) {
        $nameId{$results[$ii]} = $results[$ii+1];
        $namePropId{$results[$ii]} = $results[$ii+2];
    }
    
    $self->setNameIdMap(\%nameId);
    $self->setNamePropIdMap(\%namePropId);

    if ($DDEBUG) {
        printf STDERR "%s: nameId result=\n", ::srline();
        dumpDbKeys(\%nameId);

        printf STDERR "%s: namePropId result=\n", ::srline();
        dumpDbKeys(\%namePropId);
    }

    $self->setDbKeysInitialized(1);
    return 0;
}

sub addOneProcedure
#supports list and dump commands.
#add a single procedure to the collection.
#does not fully populate sub-objects. for that, use loadProcedures();
#return 0 on success.
{
    my ($self, $procedureName) = @_;

    #initialize procedure keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initProcedureKeys());

    #check that we have a legitimate procedure name:
    if (!defined($self->getNameIdMap->{$procedureName})) {
        printf STDERR "%s:  ERROR:  procedure '%s' is not in the database.\n", ::srline(), $procedureName;
        return 1;
    }

    #no setter, for mEcProcedureList - so use direct ref:
    push @{$self->{'mEcProcedureList'}},
        (new ecdump::ecProcedure($self, $procedureName, $self->getNameIdMap->{$procedureName}, $self->getNamePropIdMap->{$procedureName}));

    #TODO:  add procedure-level properties

    return 0;
}

sub addAllProcedures
#add all of the EC procedures to the collection.
#returns 0 on success
{
    my ($self) = @_;

    #initialize procedure keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initProcedureKeys());

    #make sure we start with a clean list, in the event this routine has already been called:
    $self->{'mEcProcedureList'} = [];

    #now add one procedure obj. per retrieved procedure:
    for my $name (sort keys %{$self->getNameIdMap()}) {
        $self->addOneProcedure($name);
    }

    return 0;
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub projectName
#return value of mProjectName
{
    my ($self) = @_;
    return $self->{'mProjectName'};
}

sub projectId
#return value of mProjectId
{
    my ($self) = @_;
    return $self->{'mProjectId'};
}

sub ecProcedureList
#return mEcProcedureList list
{
    my ($self) = @_;
    return @{$self->{'mEcProcedureList'}};
}

sub getDbKeysInitialized
#return value of DbKeysInitialized
{
    my ($self) = @_;
    return $self->{'mDbKeysInitialized'};
}

sub setDbKeysInitialized
#set value of DbKeysInitialized and return value.
{
    my ($self, $value) = @_;
    $self->{'mDbKeysInitialized'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDbKeysInitialized'};
}

sub getNameIdMap
#return value of NameIdMap
{
    my ($self) = @_;
    return $self->{'mNameIdMap'};
}

sub setNameIdMap
#set value of NameIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNameIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNameIdMap'};
}

sub getNamePropIdMap
#return value of NamePropIdMap
{
    my ($self) = @_;
    return $self->{'mNamePropIdMap'};
}

sub setNamePropIdMap
#set value of NamePropIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNamePropIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNamePropIdMap'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProcedures
{
#
#ecProject - object representing an EC Project
#

use strict;

package ecdump::ecProject;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";


#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);
our @ISA = qw(ecdump::ecProjects);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg, $projectName, $projectId, $propertySheetId) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $cfg->config(),
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpj' => $cfg->sqlpj(),
        'mRootDir' => undef,
        'mProjectName' => $projectName,
        'mProjectId' => $projectId,
        'mDescription' => '',
        'mEcProcedures' => undef,
        'mPropertySheetId' => $propertySheetId,
        'mEcProps' => undef,
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    #set output root for this project:
    $self->{'mRootDir'} = path::mkpathname($cfg->rootDir(), ec2scm($projectName));

    #create properties container object, which will contain the list of our properties:
    $self->{'mEcProps'} = new ecdump::ecProps($self, $propertySheetId);

    #create procedure container object, which will contain the list of our procedures:
    $self->{'mEcProcedures'} = new ecdump::ecProcedures($self);

    return $self;
}

################################### PACKAGE ####################################

#see also: ecProject.defs
sub loadProject
#load each project from the database
{
    my ($self, $indent) = @_;

    #first load myself the project:
    printf STDERR "%sLOADING PROJECT '%s'\n", ' 'x$indent, $self->projectName() if ($VERBOSE);

    #get my description (method defined in ecProjects):
    $self->fetchDescription('ec_project', $self->projectId);

    #load my properties:
    $self->ecProps->loadProps();

    #then load my procedures:
    $self->ecProcedures->loadProcedures();
}

sub dumpProject
#dump each project to the dump tree.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    #first dump myself the project:
    printf STDERR "%sDUMPING PROJECT '%s' -> %s\n", ' 'x$indent, $self->projectName(), $outroot if ($VERBOSE);

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    #write my description out:
    $self->dumpDescription();

    #dump my properties:
    $self->ecProps->dumpProps($indent+2);

    #then dump the procedures:
    return $self->ecProcedures->dumpProcedures($indent+2);
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub projectName
#return value of mProjectName
{
    my ($self) = @_;
    return $self->{'mProjectName'};
}

sub projectId
#return value of mProjectId
{
    my ($self) = @_;
    return $self->{'mProjectId'};
}

sub getDescription
#return value of Description
{
    my ($self) = @_;
    return $self->{'mDescription'};
}

sub setDescription
#set value of Description and return value.
{
    my ($self, $value) = @_;
    $self->{'mDescription'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDescription'};
}

sub ecProcedures
#return value of mEcProcedures
{
    my ($self) = @_;
    return $self->{'mEcProcedures'};
}

sub propertySheetId
#return value of mPropertySheetId
{
    my ($self) = @_;
    return $self->{'mPropertySheetId'};
}

sub ecProps
#return value of mEcProps
{
    my ($self) = @_;
    return $self->{'mEcProps'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProject
{
#
#ecProjects - collection of EC Projects
#

use strict;

package ecdump::ecProjects;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";


#package variables:
ecdump::utils->import;
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $cfg->config(),
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpj' => $cfg->sqlpj(),
        'mRootDir' => undef,
        'mEcProjects' => undef,
        'mDbKeysInitialized' => 0,
        'mNameIdMap' => undef,
        'mNamePropIdMap' => undef,
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #set output root for the EC projects:
    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    $self->{'mRootDir'} = path::mkpathname($cfg->rootDir(), ec2scm("projects"));

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecProjects.defs
sub loadDumpProjects
#load and dump projects one at a time instead of all at once.
#this allows us to garbage collect between projects.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    return 1 unless ($self->createOutdir() == 0);

    printf STDERR "%sDUMPING PROJECTS -> %s\n", ' 'x$indent, $outroot if ($VERBOSE);

    $self->loadEcTopLevel();
    $self->dumpEcTopLevel();

    my $errs = 0;
    for my $pj ($self->ecProjects()) {
        if ($pj->loadProject($indent+2) != 0) {
            printf STDERR "%s: ERROR:  failed to load project '%s'\n", ::srline(), $pj->projectName;
            ++$errs;
        } else {
            if ($pj->dumpProject($indent+2) != 0) {
                printf STDERR "%s: ERROR:  failed to dump project '%s'\n", ::srline(), $pj->projectName;
                ++$errs;
            }
        }
        #garbage collect the project since we are now done with it:
        $self->freeProject($pj, $indent+2);
    }

    return $errs;
}

sub loadProjects
#load each project from the database
{
    my ($self) = @_;

    $self->loadEcTopLevel();

    for my $pj ($self->ecProjects()) {
        $pj->loadProject();
    }

    return 0;
}

sub createOutdir
{
    my ($self) = @_;
    my $outroot = $self->rootDir();

    os::createdir($outroot, 0775) unless (-d $outroot);
    if (!-d $outroot) {
        printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
        return 1;
    }

    return 0;
}

sub dumpProjects
#dump each project to the dump tree.
{
    my ($self, $indent) = @_;
    my $outroot = $self->rootDir();

    printf STDERR "%sDUMPING PROJECTS -> %s\n", ' 'x$indent, $outroot if ($VERBOSE);

    return 1 unless ($self->createOutdir() != 0);

    $self->dumpEcTopLevel();

    my $errs = 0;
    for my $pj ($self->ecProjects()) {
        $errs += $pj->dumpProject($indent+2);
    }

    return $errs;
}

sub listProjectNames
#display the current list of project names
{
    my ($self) = @_;

    for my $pj ($self->ecProjects()) {
        printf "%s\n", $pj->projectName();
    }
}

sub loadEcTopLevel
#load top-level EC metadata
{
    #TBD.
    return 0;
}

sub dumpEcTopLevel
#dump top-level EC metadata
{
    #TBD.
    return 0;
}

sub addOneProject
#supports list and dump commands.
#can be called from outside (to process a list of user-supplied projects).
#add a single project to the collection.
#does not fully populate sub-objects. for that, use loadProjects();
#return 0 on success.
{
    my ($self, $projectName) = @_;

    #initialize project keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initDbKeys());

    #check that we have a legitimate project name:
    if (!defined($self->getNameIdMap->{$projectName})) {
        printf STDERR "%s:  ERROR:  project '%s' is not in the database.\n", ::srline(), $projectName;
        return 1;
    }

    #no setter, for mEcProjects - so use direct ref:
    push @{$self->{'mEcProjects'}},
        (new ecdump::ecProject($self, $projectName, $self->getNameIdMap->{$projectName}, $self->getNamePropIdMap->{$projectName}));

    #TODO:  add project-level properties

    return 0;
}

sub addAllProjects
#add all of the EC projects to the collection.
#returns 0 on success
{
    my ($self) = @_;

    #initialize project keys if not done yet:
    return 1 unless ($self->getDbKeysInitialized() || !$self->initDbKeys());

    #make sure we start with a clean list, in the event this routine has already been called:
    $self->{'mEcProjects'} = [];

    #now add one project obj. per retrieved project:
    for my $name (sort keys %{$self->getNameIdMap()}) {
        $self->addOneProject($name);
    }

    return 0;
}

sub initDbKeys
#initialize project keys.  This only needs to happen once.
#if okay, then we set DbKeysInitialized attribute to true.
#return 0 on success.
{
    my ($self) = @_;
    my ($sqlpj) = $self->sqlpj();

    my $lbuf = "select name,id,property_sheet_id from ec_project";

    printf STDERR "%s: running sql query to get project keys\n", ::srline() if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect (name,id,propId) triples.
    } @{$sqlpj->getQueryResult()};


    #map (name,id,propert_sheet_id) triples into nameId and namePropId hashes:
    my (%nameId, %namePropId);
    for (my $ii=0; $ii < $#results; $ii += 3) {
        $nameId{$results[$ii]} = $results[$ii+1];
        $namePropId{$results[$ii]} = $results[$ii+2];
    }
    
    $self->setNameIdMap(\%nameId);
    $self->setNamePropIdMap(\%namePropId);

    if ($DDEBUG) {
        printf STDERR "%s: nameId result=\n", ::srline();
        dumpDbKeys(\%nameId);

        printf STDERR "%s: namePropId result=\n", ::srline();
        dumpDbKeys(\%namePropId);
    }

    $self->setDbKeysInitialized(1);
    return 0;
}

sub fetchDescription
#pull the description for table <table>
#caller must have a setDescription(string) method.
#return 0 if successful
{
    my ($self, $table, $id) = @_;
    my ($sqlpj) = $self->sqlpj();

    #this is a result:
    $self->setDescription('');

    #this query should return only one row:
    my $lbuf = sprintf("select description, description_clob_id from %s where id=%d", $table, $id) ;

    printf STDERR "%s: running sql query to get description field\n", ::srline() if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect one row with (description,description_clob_id) pair
    } @{$sqlpj->getQueryResult()};

    if ( $#results+1 != 2 ) {
        printf STDERR "%s:  ERROR:  query '%s' returned wrong number of results (%d).\n", ::srline(), $lbuf, $#results+1;
        return 1;
    }

    my ($descStr, $descClobId) = ($results[0], $results[1]);

    $descStr    = '' unless (defined($descStr));
    $descClobId = '' unless (defined($descClobId));

    printf STDERR "%s: (descStr,descClobId)=(%s,%s)\n", ::srline(), $descStr, $descClobId if ($DDEBUG);

    #Note:  if we have a string and a clob, we prefer the clob, which is the full content

    if ($descClobId ne '') {
        my $clobtxt = '';
        if ($self->fetchClobText(\$clobtxt, $descClobId) != 0) {
            printf STDERR "%s:  ERROR:  failed to fetch description clob='%s' for %s[%s]\n", ::srline(), $descClobId, $table, $id;
            return 1;
        }
        $self->setDescription($clobtxt);
    } elsif ($descStr ne '') {
        $self->setDescription($descStr);
    }

    return 0;
}

sub fetchClobText
{
    my ($self, $txtref, $id) = @_;
    my ($sqlpj) = $self->sqlpj();

    #this is a result:
    $$txtref = '';

    #this query should return only one row:
    my $lbuf = sprintf("select clob from ec_clob where id=%d", $id);

    printf STDERR "%s: running sql query to get clob\n", ::srline() if ($DDEBUG);

    if ( !$sqlpj->sql_exec($lbuf) ) {
        printf STDERR "%s:  ERROR:  query '%s' failed.\n", ::srline(), $lbuf;
        return 1;
    }

    #o'wise, stash results (query returns a ref to a list of list refs):
    my @results = map {
        @{$_};    #dereference each row.  we expect one row containing the clob
    } @{$sqlpj->getQueryResult()};

    if ( $#results+1 != 1 ) {
        printf STDERR "%s:  ERROR:  query '%s' returned wrong number of results (%d).\n", ::srline(), $lbuf, $#results+1;
        return 1;
    }

    #otherwise we found the clob, set the result:
    $$txtref = $results[0];

    return 0;
}

sub dumpDescription
#write the description out.
#caller must have a getDescription(), rootDir  methods.
#return 0 if successful
{
    my ($self) = @_;
    my $txt = $self->getDescription();

    #don't create empty files:
    return if ($txt eq '');

    my $outroot = $self->rootDir();

    #fix eol:
    $txt = "$txt\n" unless ($txt eq '' || $txt =~ /\n$/);

    return os::write_str2file(\$txt, path::mkpathname($outroot, "description"));
}

sub freeProject
#free a project from our project list, which is the only ref to the project object
#return 0 if successful
{
    my ($self, $pj, $indent) = @_;
    my @pjs = ($self->ecProjects());

    for (my $ii=0; $ii <= $#pjs; $ii++) {
        if ( defined($pjs[$ii]) && $pjs[$ii] == $pj ) {
            #kill the reference:
            undef ${$self->{'mEcProjects'}}[$ii];
            printf STDERR "%sFREED PROJECT '%s'\n", ' 'x$indent, $pj->projectName if ($VERBOSE);
            return 0;
        }
    }

    #didn't find it:
    printf STDERR "%s:  WARNING:  could not free project %s\n", ::srline(), $pj->projectName;
    return 1;
}

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub ecProjects
#return mEcProjects list
{
    my ($self) = @_;
    return @{$self->{'mEcProjects'}};
}

sub getDbKeysInitialized
#return value of DbKeysInitialized
{
    my ($self) = @_;
    return $self->{'mDbKeysInitialized'};
}

sub setDbKeysInitialized
#set value of DbKeysInitialized and return value.
{
    my ($self, $value) = @_;
    $self->{'mDbKeysInitialized'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDbKeysInitialized'};
}

sub getNameIdMap
#return value of NameIdMap
{
    my ($self) = @_;
    return $self->{'mNameIdMap'};
}

sub setNameIdMap
#set value of NameIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNameIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNameIdMap'};
}

sub getNamePropIdMap
#return value of NamePropIdMap
{
    my ($self) = @_;
    return $self->{'mNamePropIdMap'};
}

sub setNamePropIdMap
#set value of NamePropIdMap and return value.
{
    my ($self, $value) = @_;
    $self->{'mNamePropIdMap'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mNamePropIdMap'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecProjects
{
#
#ecdumpImpl - ecdump implementation
#

use strict;

package ecdump::ecdumpImpl;
my $pkgname = __PACKAGE__;

#imports:
require "path.pl";
require "os.pl";
require "sqlpj.pl";


#package variables:
#standard debugging attributes:
my ($VERBOSE, $DEBUG, $DDEBUG, $QUIET) = (0,0,0,0);

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;

    my ($cfg) = @_;

    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mConfig' => $cfg,
        'mProgName' => $cfg->getProgName(),
        'mDebug' => $cfg->getDebug(),
        'mDDebug' => $cfg->getDDebug(),
        'mQuiet' => $cfg->getQuiet(),
        'mVerbose' => $cfg->getVerbose(),
        'mSqlpjConfig' => $cfg->getSqlpjConfig(),
        'mSqlpj' => $cfg->getSqlpjImpl(),
        'mHaveDumpCommand' => $cfg->getHaveDumpCommand(),
        'mHaveListCommand' => $cfg->getHaveListCommand(),
        'mDumpAllProjects' => $cfg->getDumpAllProjects(),
        'mProjectList' => [$cfg->getProjectList()],
        'mDoClean' => $cfg->getDoClean(),
        'mRootDir' => $cfg->getOutputDirectory(),
        'mDbConnectionInitialized' => 0,
        'mEcProjects' => undef,
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):

    #cache initial debugging and vebosity values in local package variables:
    $self->update_static_class_attributes();

    #create projects object, which will contain the list of our projects::
    $self->{'mEcProjects'} = new ecdump::ecProjects($self);

    return $self;
}

################################### PACKAGE ####################################

#see also:  ecdumpImpl.defs
sub execEcdump
#execute the ec dump command.
#by the time we get here, all arguments are parsed, checked, and stored in my config() object,
#the database connectivity is checked, and we are ready to run.
#returns 0 on success, non-zero othewise.
{

    my ($self) = @_;
    my $outroot = $self->rootDir();

    if (!$self->haveListCommand() && !$self->haveDumpCommand()) {
        printf STDERR "%s:  nothing to do - please specify a list or dump command.\n", $self->progName();
        return 0;
    }

    #output directory is defined only if we are dumping:
    if ($self->haveDumpCommand()) {
        if ($self->doClean()) {
            if ($self->cleanOutputDir() != 0) {
                printf STDERR "%s: ERROR: clean output directory step failed. ABORT\n", $self->progName();
                return 1;
            }
        } else {
            if (-d $outroot) {
                #this can give unpredictable results - warn the user.  RT 3/21/13
                printf STDERR "%s: WARNING: dumping to existing directory '%s', use -clean to remove.\n",
                    $self->progName(), $outroot unless ($QUIET);
            }
        }

        #now create output directory:
        if ($self->createOutputDir() != 0) {
            printf STDERR "%s: ERROR: create output directory step failed. ABORT\n", $self->progName();
            return 1;
        }
    }

    #initialize db connection if yet not done:
    if (!$self->getDbConnectionInitialized()) {
        printf STDERR "Initializing database connection ...\n"  if $VERBOSE;
        if ($self->initDbConnection() != 0) {
            printf STDERR "%s: ERROR: cannot get a database connection. ABORT\n", $self->progName();
            return 1;
        }
    }

    #cache handle for EcProjects object:
    my $ecprojects = $self->ecProjects();

    my $nerrs = 0;

    if ($self->haveListCommand() || $self->dumpAllProjects()) {
        $nerrs += $ecprojects->addAllProjects();
    } else {
        for my $pjname ($self->projectList()) {
            $nerrs += $ecprojects->addOneProject($pjname);
        }
    }

    if ($nerrs) {
        printf STDERR "%s:  encounterd %d ERROR%s while adding projects. ABORT\n", $self->progName(), $nerrs, ($nerrs == 1 ? '' : 'S');
        return 1;
    }

    if ($self->haveListCommand()) {
        return $self->processListCommand();
    }
    
    #otherwise, we have a dump command:
    return $self->processDumpCommand();
}

sub processDumpCommand
#process dump command.  return 0 on success.
{
    my ($self) = @_;

    my $ecprojects = $self->ecProjects();

    #tell ecProjects to load and dump projects one at a time:
    if ($ecprojects->loadDumpProjects(0) != 0) {
        printf STDERR "%s: ERROR: failed to dump one or more projects!\n", ::srline();
        return 1;
    }

    return 0;
}

sub processListCommand
#process list command.  return 0 on success.
{
    my ($self) = @_;
    my $ecprojects = $self->ecProjects();

    #tell ecProjects to list itself:
    return $ecprojects->listProjectNames();
}

sub initDbConnection
#initialize the database connection and execute the command.
{
    my ($self) = @_;
    my $sqlpj = $self->sqlpj();

    if (!$sqlpj->sql_init_connection()) {
        printf STDERR "%s: ERROR:  failed to get a database connection.\n", ::srline();
        return 1;
    }

    #tell sqlpj to always make results available via getQueryResult() instead of displaying on stdout:
    $sqlpj->setOutputToList(1);

    $self->setDbConnectionInitialized(1);
    return 0;
}

sub cleanOutputDir
#remove the output directory.  return 0 if successful.
{
    my ($self) = @_;
    my $outroot = $self->rootDir();

    printf STDERR "Deleting output dir '%s'...\n", $outroot if $VERBOSE;

    if (-d $outroot) {
        os::rm_recursive($outroot);
        if (-d $outroot) {
            printf STDERR "%s:  ERROR: can't remove output dir, '%s'\n", ::srline(), $outroot;
            return 1;
        }
    } elsif (-e $outroot) {
        #plain file or symlink, use less firepower:
        os::rmFile($outroot);
        if (-e $outroot) {
            printf STDERR "%s:  ERROR: can't remove '%s'\n", ::srline(), $outroot;
            return 1;
        }
    }

    return 0;
}

sub createOutputDir
#create the output directory.  return 0 if successful.
{
    my ($self) = @_;
    my $outroot = $self->rootDir();

    if (!-d $outroot) {
        printf STDERR "Creating output dir '%s'...\n", $outroot if $VERBOSE;

        os::createdir($outroot, 0775);
        #if still not there...
        if (!-d $outroot) {
            printf STDERR "%s: can't create output dir, '%s' (%s)\n", ::srline(), $outroot, $!;
            return 1;
        }
    }
    return 0;
}

sub cleanup
#call sqlpj cleanup.
{
    my ($self) = @_;
    $self->sqlpj->cleanup();
} 

sub config
#return value of mConfig
{
    my ($self) = @_;
    return $self->{'mConfig'};
}

sub progName
#return value of mProgName
{
    my ($self) = @_;
    return $self->{'mProgName'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub sqlpjConfig
#return value of mSqlpjConfig
{
    my ($self) = @_;
    return $self->{'mSqlpjConfig'};
}

sub sqlpj
#return value of mSqlpj
{
    my ($self) = @_;
    return $self->{'mSqlpj'};
}

sub haveDumpCommand
#return value of mHaveDumpCommand
{
    my ($self) = @_;
    return $self->{'mHaveDumpCommand'};
}

sub haveListCommand
#return value of mHaveListCommand
{
    my ($self) = @_;
    return $self->{'mHaveListCommand'};
}

sub dumpAllProjects
#return value of mDumpAllProjects
{
    my ($self) = @_;
    return $self->{'mDumpAllProjects'};
}

sub projectList
#return mProjectList list
{
    my ($self) = @_;
    return @{$self->{'mProjectList'}};
}

sub doClean
#return value of mDoClean
{
    my ($self) = @_;
    return $self->{'mDoClean'};
}

sub rootDir
#return value of mRootDir
{
    my ($self) = @_;
    return $self->{'mRootDir'};
}

sub getDbConnectionInitialized
#return value of DbConnectionInitialized
{
    my ($self) = @_;
    return $self->{'mDbConnectionInitialized'};
}

sub setDbConnectionInitialized
#set value of DbConnectionInitialized and return value.
{
    my ($self, $value) = @_;
    $self->{'mDbConnectionInitialized'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDbConnectionInitialized'};
}

sub ecProjects
#return value of mEcProjects
{
    my ($self) = @_;
    return $self->{'mEcProjects'};
}

sub update_static_class_attributes
#static class method to update package level attributess as required
#used to set verbosity and debugging for all objects of the class post-instantiation.
{
    my ($self) = @_;
    $DEBUG   = $self->getDebug();
    $DDEBUG  = $self->getDDebug();
    $QUIET   = $self->getQuiet();
    $VERBOSE = $self->getVerbose();
}

1;
} #end of ecdump::ecdumpImpl
{
#
#pkgconfig - Configuration parameters for sqlpj package
#

use strict;

package ecdump::pkgconfig;
my $pkgname = __PACKAGE__;

#imports:
require "sqlpj.pl";

#package variables:

sub new
{
    my ($invocant) = @_;
    shift @_;

    #allows this constructor to be invoked with reference or with explicit package name:
    my $class = ref($invocant) || $invocant;


    #set up class attribute  hash and bless it into class:
    my $self = bless {
        'mProgName' => undef,
        'mPathSeparator' => undef,
        'mVersionNumber' => "0.24",
        'mVersionDate' => "21-Mar-2013",
        'mDebug' => 0,
        'mDDebug' => 0,
        'mQuiet' => 0,
        'mVerbose' => 0,
        'mJdbcClassPath' => undef,
        'mJdbcDriverClass' => undef,
        'mJdbcUrl' => undef,
        'mJdbcUser' => undef,
        'mJdbcPassword' => undef,
        'mJdbcPropsFileName' => undef,
        'mSqlpjConfig' => undef,
        'mSqlpjImpl' => undef,
        'mProjectList' => undef,
        'mOutputDirectory' => '<NULL>',
        'mDoClean' => 0,
        'mHaveProjects' => 0,
        'mDumpAllProjects' => 0,
        'mHaveListCommand' => 0,
        'mHaveDumpCommand' => 0,
        'mIgnorePropertiesHash' => undef,
        'mIndexProcedureStepNameOption' => 0,
        'mHtmlDecorationOption' => 0,
        }, $class;

    #post-attribute init after we bless our $self (allows use of accessor methods):
    #initialize project list to be a ref to an empty list (was not able to do this in the hash init).
    $self->{'mProjectList'} = [];

    return $self;
}

################################### PACKAGE ####################################
sub initSqlpjConfig
{
    my ($self, $scfg) = @_;

    #init sqlpj configuration object:
    $self->setSqlpjConfig($scfg);

    #set program name used in sqlpj messages:
    $scfg->setProgName($self->getProgName());
    $scfg->setDebug  ($self->getDebug());
    $scfg->setDDebug ($self->getDDebug());
    $scfg->setQuiet  ($self->getQuiet());
    $scfg->setVerbose($self->getVerbose());

    #if user supplied a JDBC properties file ...
    if ( $self->getJdbcPropsFileName() ) {
        #... then parse it with sqlpj method ...
        $scfg->setJdbcPropsFileName($self->getJdbcPropsFileName());
        $scfg->parseJdbcPropertiesFile();

        #... and copy the results to our configuration:
        $self->copyJdbcConfigFrom($scfg);
    } else {
        #copy the jdbc config supplied by the user to the sqlpj config:
        $self->copyJdbcConfigTo($scfg);
    }
}

sub copyJdbcConfigFrom
{
    my ($self, $from) = @_;

    $self->setJdbcClassPath  ($from->getJdbcClassPath());
    $self->setJdbcDriverClass($from->getJdbcDriverClass());
    $self->setJdbcPassword   ($from->getJdbcPassword());
    $self->setJdbcUrl        ($from->getJdbcUrl());
    $self->setJdbcUser       ($from->getJdbcUser());
}

sub copyJdbcConfigTo
{
    my ($self, $to) = @_;

    $to->setJdbcClassPath  ($self->getJdbcClassPath());
    $to->setJdbcDriverClass($self->getJdbcDriverClass());
    $to->setJdbcPassword   ($self->getJdbcPassword());
    $to->setJdbcUrl        ($self->getJdbcUrl());
    $to->setJdbcUser       ($self->getJdbcUser());
}

sub getProgName
#return value of ProgName
{
    my ($self) = @_;
    return $self->{'mProgName'};
}

sub setProgName
#set value of ProgName and return value.
{
    my ($self, $value) = @_;
    $self->{'mProgName'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mProgName'};
}

sub getPathSeparator
#return value of PathSeparator
{
    my ($self) = @_;
    return $self->{'mPathSeparator'};
}

sub setPathSeparator
#set value of PathSeparator and return value.
{
    my ($self, $value) = @_;
    $self->{'mPathSeparator'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mPathSeparator'};
}

sub versionNumber
#return value of mVersionNumber
{
    my ($self) = @_;
    return $self->{'mVersionNumber'};
}

sub versionDate
#return value of mVersionDate
{
    my ($self) = @_;
    return $self->{'mVersionDate'};
}

sub getDebug
#return value of Debug
{
    my ($self) = @_;
    return $self->{'mDebug'};
}

sub setDebug
#set value of Debug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDebug'};
}

sub getDDebug
#return value of DDebug
{
    my ($self) = @_;
    return $self->{'mDDebug'};
}

sub setDDebug
#set value of DDebug and return value.
{
    my ($self, $value) = @_;
    $self->{'mDDebug'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDDebug'};
}

sub getQuiet
#return value of Quiet
{
    my ($self) = @_;
    return $self->{'mQuiet'};
}

sub setQuiet
#set value of Quiet and return value.
{
    my ($self, $value) = @_;
    $self->{'mQuiet'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mQuiet'};
}

sub getVerbose
#return value of Verbose
{
    my ($self) = @_;
    return $self->{'mVerbose'};
}

sub setVerbose
#set value of Verbose and return value.
{
    my ($self, $value) = @_;
    $self->{'mVerbose'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mVerbose'};
}

sub getJdbcClassPath
#return value of JdbcClassPath
{
    my ($self) = @_;
    return $self->{'mJdbcClassPath'};
}

sub setJdbcClassPath
#set value of JdbcClassPath and return value.
{
    my ($self, $value) = @_;
    $self->{'mJdbcClassPath'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mJdbcClassPath'};
}

sub getJdbcDriverClass
#return value of JdbcDriverClass
{
    my ($self) = @_;
    return $self->{'mJdbcDriverClass'};
}

sub setJdbcDriverClass
#set value of JdbcDriverClass and return value.
{
    my ($self, $value) = @_;
    $self->{'mJdbcDriverClass'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mJdbcDriverClass'};
}

sub getJdbcUrl
#return value of JdbcUrl
{
    my ($self) = @_;
    return $self->{'mJdbcUrl'};
}

sub setJdbcUrl
#set value of JdbcUrl and return value.
{
    my ($self, $value) = @_;
    $self->{'mJdbcUrl'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mJdbcUrl'};
}

sub getJdbcUser
#return value of JdbcUser
{
    my ($self) = @_;
    return $self->{'mJdbcUser'};
}

sub setJdbcUser
#set value of JdbcUser and return value.
{
    my ($self, $value) = @_;
    $self->{'mJdbcUser'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mJdbcUser'};
}

sub getJdbcPassword
#return value of JdbcPassword
{
    my ($self) = @_;
    return $self->{'mJdbcPassword'};
}

sub setJdbcPassword
#set value of JdbcPassword and return value.
{
    my ($self, $value) = @_;
    $self->{'mJdbcPassword'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mJdbcPassword'};
}

sub getJdbcPropsFileName
#return value of JdbcPropsFileName
{
    my ($self) = @_;
    return $self->{'mJdbcPropsFileName'};
}

sub setJdbcPropsFileName
#set value of JdbcPropsFileName and return value.
{
    my ($self, $value) = @_;
    $self->{'mJdbcPropsFileName'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mJdbcPropsFileName'};
}

sub getSqlpjConfig
#return value of SqlpjConfig
{
    my ($self) = @_;
    return $self->{'mSqlpjConfig'};
}

sub setSqlpjConfig
#set value of SqlpjConfig and return value.
{
    my ($self, $value) = @_;
    $self->{'mSqlpjConfig'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mSqlpjConfig'};
}

sub getSqlpjImpl
#return value of SqlpjImpl
{
    my ($self) = @_;
    return $self->{'mSqlpjImpl'};
}

sub setSqlpjImpl
#set value of SqlpjImpl and return value.
{
    my ($self, $value) = @_;
    $self->{'mSqlpjImpl'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mSqlpjImpl'};
}

sub getProjectList
#return list @ProjectList
{
    my ($self) = @_;
    return @{$self->{'mProjectList'}};
}

sub setProjectList
#set list address of ProjectList and return list.
{
    my ($self, @value) = @_;
    $self->{'mProjectList'} = \@value;
    $self->update_static_class_attributes();
    return @{$self->{'mProjectList'}};
}

sub pushProjectList
#push new values on to ProjectList list and return list.
{
    my ($self, @values) = @_;
    push @{$self->{'mProjectList'}}, @values;
    return @{$self->{'mProjectList'}};
}

sub getOutputDirectory
#return value of OutputDirectory
{
    my ($self) = @_;
    return $self->{'mOutputDirectory'};
}

sub setOutputDirectory
#set value of OutputDirectory and return value.
{
    my ($self, $value) = @_;
    $self->{'mOutputDirectory'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mOutputDirectory'};
}

sub getDoClean
#return value of DoClean
{
    my ($self) = @_;
    return $self->{'mDoClean'};
}

sub setDoClean
#set value of DoClean and return value.
{
    my ($self, $value) = @_;
    $self->{'mDoClean'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDoClean'};
}

sub getHaveProjects
#return value of HaveProjects
{
    my ($self) = @_;
    return $self->{'mHaveProjects'};
}

sub setHaveProjects
#set value of HaveProjects and return value.
{
    my ($self, $value) = @_;
    $self->{'mHaveProjects'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mHaveProjects'};
}

sub getDumpAllProjects
#return value of DumpAllProjects
{
    my ($self) = @_;
    return $self->{'mDumpAllProjects'};
}

sub setDumpAllProjects
#set value of DumpAllProjects and return value.
{
    my ($self, $value) = @_;
    $self->{'mDumpAllProjects'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mDumpAllProjects'};
}

sub getHaveListCommand
#return value of HaveListCommand
{
    my ($self) = @_;
    return $self->{'mHaveListCommand'};
}

sub setHaveListCommand
#set value of HaveListCommand and return value.
{
    my ($self, $value) = @_;
    $self->{'mHaveListCommand'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mHaveListCommand'};
}

sub getHaveDumpCommand
#return value of HaveDumpCommand
{
    my ($self) = @_;
    return $self->{'mHaveDumpCommand'};
}

sub setHaveDumpCommand
#set value of HaveDumpCommand and return value.
{
    my ($self, $value) = @_;
    $self->{'mHaveDumpCommand'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mHaveDumpCommand'};
}

sub getIgnorePropertiesHash
#return value of IgnorePropertiesHash
{
    my ($self) = @_;
    return $self->{'mIgnorePropertiesHash'};
}

sub setIgnorePropertiesHash
#set value of IgnorePropertiesHash and return value.
{
    my ($self, $value) = @_;
    $self->{'mIgnorePropertiesHash'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mIgnorePropertiesHash'};
}

sub getIndexProcedureStepNameOption
#return value of IndexProcedureStepNameOption
{
    my ($self) = @_;
    return $self->{'mIndexProcedureStepNameOption'};
}

sub setIndexProcedureStepNameOption
#set value of IndexProcedureStepNameOption and return value.
{
    my ($self, $value) = @_;
    $self->{'mIndexProcedureStepNameOption'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mIndexProcedureStepNameOption'};
}

sub getHtmlDecorationOption
#return value of HtmlDecorationOption
{
    my ($self) = @_;
    return $self->{'mHtmlDecorationOption'};
}

sub setHtmlDecorationOption
#set value of HtmlDecorationOption and return value.
{
    my ($self, $value) = @_;
    $self->{'mHtmlDecorationOption'} = $value;
    $self->update_static_class_attributes();
    return $self->{'mHtmlDecorationOption'};
}

sub update_static_class_attributes
#method to update package level attributess as required
{
}

1;
} #end of ecdump::pkgconfig
{
#
#ecdump - Main driver for ecdump - a tool to dump the Electric Commander database in a form that can be checked into an SCM
#

use strict;

package ecdump;
my $pkgname = __PACKAGE__;

#imports:
use Config;
require "sqlpj.pl";
require "os.pl";


#standard global options:
my $p = $main::p;
my ($VERBOSE, $HELPFLAG, $DEBUGFLAG, $DDEBUGFLAG, $QUIET) = (0,0,0,0,0);

#package global variables:
ecdump::utils->import;

my $edmpcfg = new ecdump::pkgconfig();

#sqlpj config object:
my $scfg    = new sqlpj::pkgconfig();

#this will be initialized after configuration is set up:
my $ecdumpImpl = undef;

#file containing list of projects:
my $PJLIST = undef;

#default ignore list for property sheets that we do not traverse.
#user can override this list via ECDUMP_IGNORES env. var
my %DefaultIgnorePropSheets = (
    'buildNumbers'      => 0,
    'buildResults'      => 0,
    'ec_savedSearches'  => 0,
    'ecscm_snapshots'   => 0,
    'jobsForReaping'    => 0,
);

#this is just for the usage message:
my $DefaultIgnorePropSheets = join(';', sort keys %DefaultIgnorePropSheets);

#set up based on environment:
my %IgnorePropSheets = ();

&init;      #init globals

##################################### MAIN #####################################

sub main
{
    local(*ARGV, *ENV) = @_;

    &init;      #init globals

    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);


    #we handle our own signals:
    $SIG{'INT'}  = 'ecdump::rec_signal';
    $SIG{'KILL'} = 'ecdump::rec_signal';
    $SIG{'QUIT'} = 'ecdump::rec_signal';
    $SIG{'TERM'} = 'ecdump::rec_signal';
    $SIG{'HUP'}  = 'ecdump::rec_signal';
    $SIG{'TRAP'} = 'ecdump::rec_signal';

    #if we get to here, arguments have been parsed and checked.

    my $sqlpjImpl = new sqlpj::sqlpjImpl($edmpcfg->getSqlpjConfig());
    $edmpcfg->setSqlpjImpl($sqlpjImpl);

    #######
    #create implementation class, passing in our configuration:
    #######
    $ecdumpImpl = new ecdump::ecdumpImpl($edmpcfg);

    #initialize our driver class:
    if (!$sqlpjImpl->check_driver()) {
        printf STDERR "%s:  ERROR: JDBC driver '%s' is not available for url '%s', user '%s', password '%s'\n",
            $pkgname, $ecdumpImpl->jdbcDriver(), $ecdumpImpl->getJdbcUrl(), $ecdumpImpl->user(), $ecdumpImpl->password();
        return 1;
    }

    #####
    #call ecdump implementation:
    #####
    return $ecdumpImpl->execEcdump();


    return 0;
}

################################### PACKAGE ####################################

sub checkSetClasspath
#if we have a classpath setting, then add to the environemnt.
#
#NOTE:  inline java will ignore any new CLASSPATH setting after
#       the module is loaded.  A work-around is to use "require" to load it.
{
    my ($cfg) = @_;

#printf STDERR "BEFORE CLASSPATH='%s'\n", $ENV{'CLASSPATH'};
    if (defined($cfg->getJdbcClassPath())) {
        if (defined($ENV{'CLASSPATH'}) && $ENV{'CLASSPATH'} ne "") {
            $ENV{'CLASSPATH'} = sprintf("%s%s%s", $cfg->getJdbcClassPath(), $cfg->getPathSeparator(), $ENV{'CLASSPATH'});
        } else {
            $ENV{'CLASSPATH'} = $cfg->getJdbcClassPath();
        }
    }
#printf STDERR "AFTER CLASSPATH='%s'\n", $ENV{'CLASSPATH'};
}

sub checkJdbcSettings
#return true(1) if jdbc properties are all defined.
{
    my ($cfg) = @_;
    my $errs = 0;

    if (!defined($cfg->getJdbcDriverClass())) {
        ++$errs; printf STDERR "%s:  missing JDBC driver class\n", $p;
    }
    if (!defined($cfg->getJdbcUrl())) {
        ++$errs; printf STDERR "%s:  missing JDBC URL\n", $p
    }
    if (!defined($cfg->getJdbcUser())) {
        ++$errs; printf STDERR "%s:  missing JDBC User name\n", $p;
    }
    if (!defined($cfg->getJdbcPassword())) {
        ++$errs; printf STDERR "%s:  missing JDBC User password\n", $p;
    }

    return($errs == 0);
}

sub parseEcdumpIgnores
#parse ECDUMP_IGNORE environment variable if it is defined:
#returns a reference to the ignore hash.
{
    if (defined($ENV{'ECDUMP_IGNORES'})) {
        my @ignores = split(';', $ENV{'ECDUMP_IGNORES'});

        if ($#ignores >= 0) {
            #set global IgnorePropSheets to contents of ECDUMP_IGNORES:
            %IgnorePropSheets = map {
                $_, 0;
            } @ignores;
        } else {
            printf STDERR "%s: WARNING:  ECDUMP_IGNORES defined, but empty - setting default ignores.\n", $p;
            %IgnorePropSheets = %DefaultIgnorePropSheets;
        }
    } else {
        %IgnorePropSheets = %DefaultIgnorePropSheets;
    }

    return \%IgnorePropSheets;
}

sub rec_signal
# we only want to abort sqlexec in progress, not program.
{
    local($SIG) = @_;
    my($prevHandler) = $SIG{$SIG};

    # Reestablish the handler.
    $SIG{$SIG} = $prevHandler;
    printf STDERR ("\n%s:  Received SIG%s%s\n", $p, $SIG, ($SIG eq "HUP")? " - IGNORED" : "");

    #note - this calls my cleanup:
    main::abort("Shutting down.\n");
}

#################################### USAGE #####################################

sub usage
{
    my($status) = @_;

    print STDERR <<"!";
Usage:  $pkgname [options] [project_names]

SYNOPSIS
  Connect to an Electric Commander database and dump named EC projects,
  including procedure and property hierarchy.

  If -dump is specified, and no projects are named, then dump all projects.

OPTIONS
  -help             Display this help message.
  -V                Show the $pkgname version.
  -verbose          Display additional informational messages.
  -debug            Display debug messages.
  -ddebug           Display deep debug messages.
  -quiet            Display severe errors only.

  -list             List all projects and exit.
  -dump dirname     Dump any named projects, output rooted at <dirname>.
  -P file           Dump only the projects listed in <file>.
  -clean            Remove <dirname> prior to dump.

  -indexsteps       Add index prefixes to dump of procedure step names dirs, e.g. "01_foostep"
  -addhtml          Decorate dump with browser-friendly html indexes.

                    ===============
                    JDBC PROPERTIES
                    ===============
  -props file       A java property file containing the JDBC connection parameters.
                    The following property keys are recognized:

                        JDBC_CLASSPATH, JDBC_DRIVER_CLASS,
                        JDBC_URL, JDBC_USER, JDBC_PASSWORD

  -classpath string Classpath containing the JDBC driver (can be a single jar).
  -driver classname Name of the driver class
  -url name         Jdbc connection url
  -user name        Username used for connection
  -password string  Password for this user

ENVIRONMENT

  ECDUMP_IGNORES    List of EC property sheet names to ignore, delimited by semi-colons.
  DEFAULT: ECDUMP_IGNORES="$DefaultIgnorePropSheets"

  CLASSPATH         Java CLASSPATH, inherited by JDBC.pm

  PERL_INLINE_JAVA_EXTRA_JAVA_ARGS
                    Extra args for java vm, e.g. -Xmx1024m to increase memory.

EXAMPLES
  Initialize JDBC properties and dump EC projects to directory `ecbackup'.
      $pkgname -props ~/.jdbc/lcommander.props ecbackup

SEE ALSO
 sqlpj(1) - used to provide database connectivity via JDBC.

!
    return ($status);
}

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;

    #set defaults:
    $edmpcfg->setProgName($p);
    $edmpcfg->setPathSeparator($Config{path_sep});

    #eat up flag args:
    my ($flag);
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag =~ '^-debug') {
            $DEBUGFLAG = 1;
        } elsif ($flag =~ '^-V') {
            # -V                show version and exit
            printf STDOUT "%s, Version %s, %s.\n",
                $edmpcfg->getProgName(), $edmpcfg->versionNumber(), $edmpcfg->versionDate();
            $HELPFLAG = 1;   #this forces exit.
            return 0;
        } elsif ($flag =~ '^-addhtml') {
            # -addhtml          Decorate dump with browser-friendly html indexes.
            $edmpcfg->setHtmlDecorationOption(1);
            printf STDERR "%s: TODO:  implement -addhtml option.\n", $p;
        } elsif ($flag =~ '^-indexsteps') {
            # -indexsteps             add index prefixes to all procedure step names, e.g. "01_foostep"
            $edmpcfg->setIndexProcedureStepNameOption(1);
        } elsif ($flag =~ '^-list') {
            # -list             List all projects and exit.
            $edmpcfg->setHaveListCommand(1);
        } elsif ($flag =~ '^-clean') {
            # -clean            Remove <dirname> prior to dump.
            $edmpcfg->setDoClean(1);
        } elsif ($flag =~ '^-dump') {
            # -dump dirname     Dump named projects, output rooted at <dirname>.
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $edmpcfg->setOutputDirectory(shift @ARGV);
                $edmpcfg->setHaveDumpCommand(1),
            } else {
                printf STDERR "%s:  -dump requires directory name.\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-P') {
            # -P file - get the list of projects to dump from <file>
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $PJLIST = shift @ARGV;
            } else {
                printf STDERR "%s:  -P requires file containing list of projects to dump.\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-user') {
            # -user name        Username used for connection
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $edmpcfg->setJdbcUser(shift(@ARGV));
            } else {
                printf STDERR "%s:  -user requires user name.\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-pass') {
            # -password string  Password for this user
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $edmpcfg->setJdbcPassword(shift(@ARGV));
            } else {
                printf STDERR "%s:  -password requires password string.\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-driver') {
            # -driver classname Name of the driver class
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $edmpcfg->setJdbcDriverClass(shift(@ARGV));
            } else {
                printf STDERR "%s:  -driver requires driver class name.\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-classpath') {
            # -classpath string Classpath containing the JDBC driver (can be a single jar).
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $edmpcfg->setJdbcClassPath(shift(@ARGV));
            } else {
                printf STDERR "%s:  -classpath requires classpath setting.\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-props') {
            # -props <file>        Set JDBC connection properties from <file>
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $edmpcfg->setJdbcPropsFileName(shift(@ARGV));
            } else {
                printf STDERR "%s:  -props requires a file name containing JDBC connection properties.\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-url') {
            # -url name         Jdbc connection url
            if ($#ARGV+1 > 0 && $ARGV[0] !~ /^-/) {
                $edmpcfg->setJdbcUrl(shift(@ARGV));
            } else {
                printf STDERR "%s:  -url requires the JDBC connection url\n", $p;
                return 1;
            }
        } elsif ($flag =~ '^-dd') {
            $DDEBUGFLAG = 1;
        } elsif ($flag =~ '^-v') {
            $VERBOSE = 1;
        } elsif ($flag =~ '^-q') {
            $QUIET = 1;
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    #set debug, verbose options:
    $edmpcfg->setDebug($DEBUGFLAG);
    $edmpcfg->setDDebug($DDEBUGFLAG);
    $edmpcfg->setQuiet($QUIET);
    $edmpcfg->setVerbose($VERBOSE);

    $edmpcfg->setIgnorePropertiesHash(parseEcdumpIgnores());

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    #if we have a file containing list of projects, process that first:
    my @plist = ();

    if ($PJLIST) {
        if (!-r $PJLIST) {
            printf STDERR "%s:  cannot read project list from '%s'\n", $p, $PJLIST;
            return 1;
        }

        #othewise, see if we can open it:
        my $tmp = "";
        if (os::read_file2str(\$tmp, $PJLIST) != 0) {
            printf STDERR "%s:  cannot read project list from '%s'\n", $p, $PJLIST;
            return 1;
        }

        @plist = split(/[\r\n]/, $tmp);

        #eliminate empty or commented lines:
        @plist = grep(!/^\s*$/, @plist);    #empty or blank lines
        @plist = grep(!/^\s*#/, @plist);    #comments
    }

    #do we have a list of projects?
    push @plist, @ARGV if ($#ARGV >= 0);

    if ($#plist >= 0) {
        $edmpcfg->setProjectList(@plist);
        $edmpcfg->setHaveProjects(1);
        $edmpcfg->setDumpAllProjects(0);
    }


    if ($edmpcfg->getHaveDumpCommand() && $edmpcfg->getHaveListCommand()) {
        printf STDERR "%s: WARN:  -dump and -list specified - will do -list only.\n", $p unless($QUIET);
        $edmpcfg->setHaveDumpCommand(0);
    }

    if ($edmpcfg->getHaveDumpCommand() && !$edmpcfg->getHaveProjects()) {
        printf STDERR "%s: INFO:  dump specified, but no projects specified - will dump all projects.\n", $p unless($QUIET);
        $edmpcfg->setDumpAllProjects(1);
    }

    if ($edmpcfg->getHtmlDecorationOption() && $edmpcfg->getIndexProcedureStepNameOption(1)) {
        printf STDERR "%s: WARN:  -indexsteps and -addhtml specified - will do -addhtml only.\n", $p unless($QUIET);
        $edmpcfg->setIndexProcedureStepNameOption(0);
    }

    #####
    # this doesn't work here - had to make it global.  no idea why.  RT 2/15/13
    #   my $scfg = new sqlpj::pkgconfig();
    #   get:  Undefined subroutine &sqlpj::pkgconfig
    #####

    $edmpcfg->initSqlpjConfig($scfg);

    #check the JDBC configuration:
    if (!$edmpcfg->getSqlpjConfig->checkJdbcSettings()) {
        printf STDERR "%s:  one or more JDBC connection settings are missing or incomplete - ABORT.\n", $p;
        return 1;
    }

    #add to the CLASSPATH if required:
    $edmpcfg->getSqlpjConfig->checkSetClasspath();

    #initialize util debug settings:
    init_utils($edmpcfg);
    return 0;
}

################################ INITIALIZATION ################################

sub init
{
}

sub cleanup
{
    printf STDERR "%s:  clean-up has been called!\n", $p if ($DEBUGFLAG);
    if (defined($ecdumpImpl)) {
        $ecdumpImpl->cleanup();
    }
}

1;
} #end of ecdump
