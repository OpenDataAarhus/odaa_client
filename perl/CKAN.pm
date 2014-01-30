package CKAN;
#
# Fejlhåndtering er ikke-eksisterende f.eks. manglende parametre eller forkerte data
# En metode kunne være at gemme sidste fejl i ckan-obj (self) som så kan hentes via særlig metode
# 
# Funktion create (bedre navn?) udskriver diverse info som evt. kun skulle udskrives i debugmode eller gemmes i ckan-obj
#
# Generel info: http://docs.ckan.org/en/ckan-2.0.3/api.html
#
use strict;
use HTTP::Tiny;
use URI;
use JSON;
#use Data::Dump qw/dump/;
my @attributes;

BEGIN {
  @attributes= qw(debug baseurl organisation package_name package_title resource_name fields);
}

sub new {
  my($class, %args) = @_;

  my $self = {
       http => HTTP::Tiny->new( default_headers => {
                                      'Content-type' => 'application/json; charset=utf-8',
                                      'Authorization' => $args{apikey},
                                      }),
       filecounter => 0,
  };

  for my $key ( @attributes ) {
    $self->{$key} = $args{$key} if exists $args{$key}
  }

  return bless $self, $class;
}

sub get_organisations_id {
  # helper-function for search organisation
  my ($self, $organization) = @_;

   my $result = $self->ckan_function( 'organization_list', { all_fields => 'true'} );

   return unless defined $result;

   foreach(@$result){
     return $_->{id} if $_->{title} eq $organization;
   }
}

sub ckan_url {
  # helper-function for correct ckan url
  my ($self, $function, $query)=@_;

  my $uri = URI->new($self->{baseurl});
  $uri->path( 'api/3/action/' . $function);
  $uri->query_form( $query ) if $query;
  return $uri->as_string;
}

sub create {
  # helper function; package/resource oprettes hvis nødvendigt
  my ($self) = @_;

  my $organizations_id = $self->get_organisations_id($self->{organisation});
  return unless $organizations_id;
  print 'organisation found: ', $organizations_id, "\n";

  my $result;

  # PACKAGE
  # søg efter package om den findes i forvejen
  $result = $self->ckan_function('package_show', { id => $self->{package_name}} ); # name or id
  if ( !defined $result ) {
    # ikke fundet - vi prøver at oprette
    $result = $self->ckan_function('package_create', { name => $self->{package_name}, title => $self->{package_title}, owner_org => $organizations_id} );
    return unless defined $result;
  }
  my $package_id = $result->{id};
  print 'package found: ', $package_id, "\n";

  # Package fundet/oprettet - eksisterende resourcers metadata findes i allerede hentede data som søges igennem
  my $resource_obj;
  foreach(@{$result->{resources}}){
    if ( $_->{name} eq $self->{resource_name} ) {
      $resource_obj = $_;
      print 'resource found: ';
      last;
    }
  }

  # IKKE fundet - forsøg at oprette...
  if ( ! defined $resource_obj) {
    $resource_obj = $self->ckan_function('resource_create', { package_id => $package_id, url => 'http://dummy', name => $self->{resource_name}} );
    return unless defined $resource_obj;
    print 'resource created: ';
  }
  my $resource_id = $resource_obj->{id};  
  
  print $resource_id, "\n";

  # OPDATER RESOURCE - hvis nødvendigt
  my $url = $self->ckan_url('datastore_search', { resource_id => $resource_id});
  if ( $url ne $resource_obj->{url} ) {
    $result = $self->ckan_function('resource_update', { id => $resource_id, url => $url } );
    return unless defined $result;
    print "url updated\n";
  } else {
    print "url ok\n"; 
  }

  # DATASTORE OPRETTES evt med fields / index
  my $data =  { resource_id => $resource_id };
  $data->{fields} = $self->{fields} if exists $self->{fields};
  $data->{indexes} = $self->{indexes} if exists $self->{indexes};

  $result = $self->ckan_function('datastore_create', $data );
  return unless defined $result;
  print "datastore created/updated\n";

  return $resource_id;
}


sub ckan_function {
  # The real working horse
  my ( $self, $function, $data )=@_;

  my $json = JSON->new->allow_nonref(1)->utf8(1);

  my $url = $self->ckan_url($function);

  my $jsondata = $json->encode( $data );

  my $response = $self->{http}->request('POST', $url, { content => $jsondata } );

  # hvis debug er aktiveret gemmes data
  if($self->{debug}){
    $self->{filecounter}++;

    open(DATA, ">:utf8", $self->{debug} . '-' . $self->{filecounter} . ".txt" );
    print DATA $url, "\n", $jsondata, "\n";
    print DATA $response->{content}, "\n" ;
    #print DATA dump($response);
    close(DATA);
  }

  # server kan give andre typer fejl end 200 og så ER der ingen relevante data
  return unless $response->{status} == 200;

  # hvis status er ok så antages at indholdet ER json
  my $result = $json->decode( $response->{content} );

  return ($result && $result->{success} eq 'true' ? $result->{result} : undef );
}


1;
