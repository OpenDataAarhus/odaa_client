<?php

function simple_http_request($url, $headers = array(), $method = 'GET', $data = NULL) {
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
