<?php

print create_odaa();

function create_odaa () {

    $odaa_site = 'http://ODAA_SITE';
    $odaa_apikey = 'YOUR PERSONAL APIKEY FROM ODAA';
    $odaa_resource_id = 'THE RESOURCE ID';

    $odaa_url = $odaa_site . '/api/3/action/datastore_create';

    if ( !$odaa_apikey || !$odaa_url || !$odaa_resource_id ) {
      return;
    }

    $data = array( 'resource_id' => $odaa_resource_id,
                'fields' => array(
                    // EXAMPLES FIELD
                    array( 'id' => 'id' , 'type' => 'int' ),
                    array( 'id' => 'title' , 'type' => 'text' ),
                    array( 'id' => 'time' , 'type' => 'timestamp' ),
                    array( 'id' => 'price', 'type' => 'float' ),
                    // ...

                   ),
                 // EXAMPLE INDEX
                 'primary_key' => array('id')
            );

    $headers = array('Content-type' => 'application/json; charset=utf-8', 'Authorization' => $odaa_apikey);

    // This template are based on the drupal
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

  return $result;
}

?>