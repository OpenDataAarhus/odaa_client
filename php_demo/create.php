<?php

include('request-include.php');

$config = [
  'site' => 'https://portal.opendata.dk',
  'apikey' => '...',
  'package_id' => 'test-api',
  'name' => 'Demosæt',
  ];

print "Ressource ID: " . create_odaa($config)."\n";

function create_odaa ($config) {

    if ( !$config['apikey'] || !$config['site'] || !$config['package_id'] ) {
      return;
    }

    $url = $config['site'] . '/api/3/action/datastore_create';

    $data = [ 'resource' => [ 'package_id' => $config['package_id'],
                              'name' => $config['name']
                            ],
                'fields' => [
                    [ 'id' => 'id' , 'type' => 'int' ],
                    [ 'id' => 'title' , 'type' => 'text' ],
                    [ 'id' => 'time' , 'type' => 'timestamp' ],
                    [ 'id' => 'price', 'type' => 'float' ],
                   ],
                'primary_key' => ['id']
            ];

    $headers = [ 'Content-type' => 'application/json; charset=utf-8', 'Authorization' => $config['apikey'] ];

    $resp = simple_http_request($url, $headers, 'POST', json_encode($data) );

    $result = json_decode($resp->data);
    
    if( isset($result->success) && $result->success ) {
      return $result->result->resource_id;
    } else {
      print_r($result);
      return 'Error';
    }
     
}

?>
