#
# simpelt script til upload af data til allerede oprettet ressource 
# erstat APIKEY og RESOURCEID med relevante værdier
#

  use strict;
  use JSON;
  use HTTP::Tiny;
  use Data::Dumper;
  use Text::CSV_XS;
  use utf8;

  # sædvanlige konfigurationsvariable
  my $config = {
    'site' => 'https://portal.opendata.dk',
    'apikey' => 'APIKEY',
    'resource_id' => 'RESOURCEID'
  };

  # hent demodata  
  my $records = load_data('data.csv');

  # send data 
  print Dumper(send_data($config, $records));

sub load_data {
  # henter data fra csv-fil - header i første linje
  my ( $file )= @_;
  my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 }) or die "Cannot use CSV: ".Text::CSV->error_diag ();
  open my $fh, "<", $file or die $!;
  binmode $fh;
  $csv->header($fh);
  my $records = $csv->getline_hr_all ($fh);
  close $fh;
  return $records;
}

sub send_data {
  # sender data - kræver at ressource er oprettet tidligere
  my($config, $records)=@_;

  if ( !$config->{apikey} || !$config->{site} ) {
      return;
  }

  # konstruer urlen til indsættelse af data
  my $url = $config->{site} . '/api/3/action/datastore_upsert';

  # pak data sammen - indeholder den konkrete ressource, data og metoden 
  my $data = { resource_id => $config->{resource_id}, records => $records, method => 'insert' };

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
