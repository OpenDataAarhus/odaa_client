<?php

$result = array();

// EXAMPLE RECORD
$record = array( 'id' => 1, 'title' => 'test', 'time' => '2013-11-11T12:23:34', 'price' => 19.95 );

$result[] = $record;

print send_data_to_odaa($result);

function send_data_to_odaa ($rec) {

    $odaa_site = 'http://ODAA_SITE';
    $odaa_apikey = 'YOUR PERSONAL APIKEY FROM ODAA';
    $odaa_resource_id = 'THE RESOURCE ID';

    $odaa_url = $odaa_site . '/api/3/action/datastore_upsert';

    if ( !$odaa_apikey || !$odaa_url || !$odaa_resource_id ) {
      return;
    }

    $data = array( 'resource_id' => $odaa_resource_id, 'records' => $rec );
    $headers = array('Content-type' => 'application/json; charset=utf-8', 'Authorization' => $odaa_apikey);

    $resp = simple_drupal_http_request($odaa_url, $headers, 'POST', json_encode($data) );

    $result = json_decode($resp->data);

    return (isset($result->success) && $result->success) ? 'OK' : 'ERROR';

}

function simple_drupal_http_request($url, $headers = array(), $method = 'GET', $data = NULL) {
  // simple replacement for drupal_http_request without error-checking 

  $ch = curl_init();

  curl_setopt($ch, CURLOPT_URL, $url);

  curl_setopt($ch, CURLOPT_POST, 1);

  $curlheaders = array();
  foreach ( $headers as $k => $v ) {
    $curlheaders[] = $k . ': ' . $v;
  }

  curl_setopt($ch, CURLOPT_HTTPHEADER, $curlheaders);

  curl_setopt($ch, CURLOPT_POSTFIELDS, $data);

  // Return the transfer as a string.
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

  // $output contains the output string.
  $result = new stdClass;
  $result->data = curl_exec($ch);

  // Close curl resource to free up system resources.
  curl_close($ch);

  print $result->data ;

  return $result;
}

?>
