<?php


include('request-include.php');

$config = [
    'site' => 'https://portal.opendata.dk',
    'apikey' => '...',
    'package_id' => 'test-api',
    'name' => 'Demosæt',
    'resource_id' => '...'
  ];

$records = [ 
            [ 'id' => 1, 'title' => 'test',  'time' => '2018-06-21T12:23:34', 'price' => 10.50 ],
            [ 'id' => 2, 'title' => 'test2', 'time' => '2018-06-20T12:23:34', 'price' => 19.95 ]
          ];


print send_data($config, $records);

function send_data ($config, $records) {

    if ( !$config['apikey'] || !$config['site'] || !$config['resource_id'] ) {
      return;
    }

    $url = $config['site'] . '/api/3/action/datastore_upsert';
    
    $data = array( 'resource_id' => $config['resource_id'], 'records' => $records );
    
    $headers = array('Content-type' => 'application/json; charset=utf-8', 'Authorization' =>  $config['apikey'] );

    $resp = simple_http_request($url, $headers, 'POST', json_encode($data) );

    $result = json_decode($resp->data);

    return (isset($result->success) && $result->success) ? 'OK' : 'ERROR';

}
