#
# simpelt script til oprettelse af ressource under et givet og allerede oprettet datasæt
# erstat APIKEY med relevante værdier
#
  use strict;
  use JSON;
  use HTTP::Tiny;
  use Data::Dumper;
  use utf8;

  # sædvanlige konfigurationsvariable
  my $config = {
    'site' => 'https://portal.opendata.dk',
    'apikey' => 'APIKEY',
    'package_id' => 'test-aarhus',
    'name' => 'Demosæt',
  };

print Dumper(create_resource($config));

sub create_resource {
  my ($config)=@_;
  
  # simpel test på parametre
  if ( !$config->{apikey} || !$config->{site} || !$config->{package_id} ) {
      return;
  }

  # konstruer urlen til oprettelsen af ressourcen
  my $url = $config->{site} . '/api/3/action/datastore_create';

  # pak data sammen i variabel
  # her defineres tabellen via fields
  # ingen primary_key eller indexes
  my $data = { resource => { package_id => $config->{package_id},
                             name => $config->{name}
                           },
               fields => [
                          { id => 'type' ,   type => 'text' },
                          { id => 'faust',   type => 'text' },
                          { id => 'count' ,  type => 'int' },
                          { id => 'date',    type => 'date' },
                       ],
          };

  my $json = JSON->new->utf8(1);

  # encode data som json
  my $jsondata = $json->encode( $data );

  # konstruer http-object
  my $http = HTTP::Tiny->new( default_headers => {
                                      'Content-type' => 'application/json; charset=utf-8',
                                      'Authorization' => $config->{apikey},
                                      });

  # og send data									  
  my $response = $http->request('POST', $url, { content => $jsondata } );

  # simpelt server-fejlcheck
  return unless $response->{status} == 200;

  my $result = $json->decode( $response->{content} );

  # returnér resultatet hvis det gik godt
  return ($result && $result->{success} ? $result->{result} : undef );

}