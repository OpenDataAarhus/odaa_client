package CKAN;
#
# Fejlhåndtering er ikke-eksisterende f.eks. manglende parametre eller forkerte data
# En metode kunne være at gemme sidste fejl i ckan-obj (self) som så kan hentes via særlig metode
#
# Funktion create (bedre navn?) udskriver diverse info som evt. kun skulle udskrives i debugmode eller gemmes i ckan-obj
#
# Generel info: http://docs.ckan.org/en/ckan-2.0.3/api.html

# 20160204: adding get_max_value_from_resource
# 20160615: adding send_data
#
#
#
use strict;
use HTTP::Tiny;
use JSON;
use Time::Piece;
#use Data::Dumper;
my @attributes;

BEGIN {
  @attributes= qw(apikey apikey_owner debug baseurl organisation package_name package_title resource_name fields indexes primary_key resource_id update_resource_id);
}

sub new {
  my($class, %args) = @_;

  my $self = {
     filecounter => 0,
  };
  if ( exists $args{file} ){
    # skal håndtere begge formater
    #  - gammelt med alle værdier i samme niveau 
    #  - nyt hvor ikke-ckan-værdier er lagt under 'data'

    open(DATA, $args{file} ) or die $!;
    local $/;
    my $json_text = <DATA>;
    close(DATA);
    my $config = JSON->new()->utf8(1)->decode( $json_text );

    my %ckan_parms = map { $_ => 1 } @attributes;

    #
    # alle "data" overføres straks
    # er der yderligere "ugyldige" værdier lægges de også i data 
    #
    if ( exists $config->{data}){
      $self->{data} = $config->{data};
    }
    foreach(keys %$config){
      next if /^data$/; # skip data der er håndteret
      if ( exists $ckan_parms{$_} ) {
        $self->{$_} = $config->{$_};
      } else {
        $self->{data}{$_} = $config->{$_};
      }
    }
    $self->{file} = $args{file};

  } else {
    foreach ( @attributes ) {
      $self->{$_} = $args{$_} if exists $args{$_}
    }
  }

  $self->{http} = HTTP::Tiny->new( default_headers => {
                                      'Content-type' => 'application/json; charset=utf-8',
                                      'Authorization' => $self->{apikey},
                                      });

  # construct url to later use:
  if ( exists $self->{baseurl} ) {
    $self->{_baseurl}  = $self->{baseurl};
    $self->{_baseurl} .= '/' unless $self->{_baseurl} =~ m!/$!;
  }
  return bless $self, $class;

}


sub save_config {
  # gemmer tidligere indlæste data
  # filnavn kan udelades hvorefter der gemmes i den originale
  # dør hvis der ikke er et filnavn

  my $self = shift;
  my $file = shift // $self->{file};

  my $ref;
  foreach(@attributes){
    $ref->{$_} = $self->{$_} if exists $self->{$_}
  }
  if ( exists $self->{data}){
    $ref->{data} = $self->{data};
  }

  my $json_text = JSON->new()->utf8(1)->canonical(1)->pretty->encode( $ref );
  # eller skulle der bruges Try::Tiny her
  
  open(DATA, '>'. $file ) or die $!;
  print DATA $json_text;
  close(DATA);
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

  my $url = $self->{_baseurl} . 'api/3/action/' . $function;
  $url .= '?' . $self->{http}->www_form_urlencode( $query ) if $query;
  return $url;
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

    my $url = 'http://portal.opendata.dk/random_uri';
    print "Trying $url\n";

    $resource_obj = $self->ckan_function('resource_create', { package_id => $package_id, url => $url, name => $self->{resource_name}, format => "csv" });
    return unless defined $resource_obj;
    print "resource created\n";
  }
  my $resource_id = $resource_obj->{id};

  print 'id=', $resource_id, "\n";
  print 'url (old)=', $resource_obj->{url}, "\n";

  # OPDATER RESOURCE - hvis nødvendigt
  my $url = $self->ckan_url('datastore_search', { resource_id => $resource_id});
  print 'url=', $url, "\n";

  if ( $url ne $resource_obj->{url} ) {
    $result = $self->ckan_function('resource_update', { id => $resource_id, url => $url, format => "csv" } );
    return unless defined $result;
    print "url updated\n";
  } else {
    print "url ok\n";
  }

  # DATASTORE OPRETTES evt med fields / index / primary_key
  my $data =  { resource_id => $resource_id };
  $data->{fields} = $self->{fields} if exists $self->{fields};
  $data->{indexes} = $self->{indexes} if exists $self->{indexes};
  $data->{primary_key} = $self->{primary_key} if exists $self->{primary_key};

  $result = $self->ckan_function('datastore_create', $data );
  return unless defined $result;
  print "datastore created/updated\n";

  # save in object
  $self->{resource_id} = $resource_id;

  return $resource_id;
}

sub ckan_function {
  # The real working horse
  my ( $self, $function, $data )=@_;

  my $json = JSON->new->allow_nonref(1)->utf8(1);

  my $url = $self->ckan_url($function);

  $data->{force} = "true";

  my $jsondata = $json->encode( $data );

  my $response = $self->{http}->request('POST', $url, { content => $jsondata } );

  # hvis debug er aktiveret gemmes data
  if($self->{debug}){
    $self->{filecounter}++;

    open(DATA, ">:utf8", $self->{debug} . '-' . $self->{filecounter} . ".txt" );
    print DATA $url, "\n", $jsondata, "\n";
    print DATA $response->{content}, "\n" ;
    close(DATA);
  }

  # server kan give andre typer fejl end 200 og så ER der ingen relevante data
  return unless $response->{status} == 200;

  # hvis status er ok så antages at indholdet ER json
  my $result = $json->decode( $response->{content} );

  return ($result && $result->{success} ? $result->{result} : undef );
}

sub delete_all_data_from_resource {
  my ($self)=@_;

  my $data = { resource_id => $self->{resource_id} };

  my $result = $self->ckan_function('datastore_delete', $data );# DELETE

  return ($result && $result->{success} ? $result->{result} : undef );
}

sub delete_some_data_from_resource {
  my ($self, $id)=@_;

  $id += 0;
  return unless $id;

  my $data = { resource_id => $self->{resource_id}, filters => { '_id' => $id } };

  my $result = $self->ckan_function('datastore_delete', $data );# DELETE

  return ($result && $result->{success} ? $result->{result} : undef );
  
}

sub get_info_from_resource {
  my ($self)=@_;

  my $data = { id => $self->{resource_id} };

  my $result = $self->ckan_function('datastore_info', $data ); # INFO

  return ($result && $result->{success} ? $result->{result} : undef );

}

sub get_size_of_resource {
#
# henter fra den aktuelle ressource max-værdien af det ønskede felt
#
  my ($self, $field)=@_;

  my $data = { sql => 'SELECT count(*) as "' . $field . '" from "' . $self->{resource_id} . '"' };

  my $result = $self->ckan_function('datastore_search_sql', $data );

  return ( defined $result ? $result->{records}[0]{$field} : undef);
}

sub get_max_value_from_resource {
#
# henter fra den aktuelle ressource max-værdien af det ønskede felt
#
  my ($self, $field)=@_;

  my $data = { sql => 'SELECT max('.$field.') as "' . $field . '" from "' . $self->{resource_id} . '"' };

  my $result = $self->ckan_function('datastore_search_sql', $data );

  return ( defined $result ? $result->{records}[0]{$field} : undef);
}

sub send_data {
#
# Sender data via angiven metode
#
  my ( $self, $method, $data )=@_;

  my $max = 1000;
  my $count = 0;
  while ( $#$data > -1 ) {

    my $localrec = [ splice(@$data, 0, $max) ];

    my $result = $self->ckan_function('datastore_upsert', { resource_id => $self->{resource_id}, records => $localrec,  method => $method } );
    sleep(1);

    if ($result) {
      $count += $#{$result->{records}}+1;
    } else {
      return;
    }
  }
  return $count;
}

sub dump_data {
  my ( $self, $file )=@_;

  # my $self = shift;
  # my $file = shift;
  # my $offset = shift // 0;
  # my $limit = shift // 100000;


 # data_dict = {
      # 'resource_id': resource_id,
      # 'limit': request.GET.get('limit', 100000),
      # 'offset': request.GET.get('offset', 0)
  # }

  my $dumpurl = $self->{_baseurl} . 'datastore/dump/' . $self->{resource_id};

  my $limit = 50000;
  my $offset = 0;

  unlink $file if -e $file;

  my $count = 0;

  LOOP:
  {
    my $params = $self->{http}->www_form_urlencode( { limit => $limit, offset => $offset}  );
    my $url = $dumpurl . '?' . $params;

    my $response = $self->{http}->get($url);

    return 0 unless $response->{success};


    # If the REPLACEMENTLIST is empty, the SEARCHLIST is replicated. This latter is useful for counting characters in a class
    my $nr_of_lines = $response->{content} =~ tr/\n//;
    $count += $nr_of_lines;

    # fjern optælling af headeren
    $count -= 1;

    if ( $offset > 0 ) {
       # fjern 1. linje
       $response->{content} =~ s/^.*[\r\n]+//;
    }

    # gem data
    #
    #
    open(DATA, ">>$file");
    binmode(DATA);
    print DATA $response->{content};
    close(DATA);


    # hvis der er præcis "limit"-linjer så kan der være mere at hente - hvis der er færre har vi hentet det ønskede
    if ( $nr_of_lines == $limit +1 ) {
      # potentielt mere indhold
      $offset += $limit;
      redo LOOP;
    }
  }
  return $count;

}


sub send_update_time {
  my ( $self, $frequency, $count)=@_;

  return unless exists $self->{update_resource_id};

  $frequency+= 0;
  $count += 0;

  my $records = [ { resource_id => $self->{resource_id}, date => Time::Piece->new->datetime, frequency => $frequency, count => $count } ];

  my $result = $self->ckan_function('datastore_upsert', { resource_id => $self->{update_resource_id}, records => $records,  method => 'upsert' } );

}


1;
