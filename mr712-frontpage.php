<?php
/**
 * Plugin Name: MR712 DDLC Front Page
 * Description: Serves the static DDLC-style choice screen (home/index.html) as the site front page. Remove this file to restore the normal WordPress front page.
 * Version:     1.0
 */

if (!defined('ABSPATH')) { exit; }

add_filter('template_include', function ($template) {
    if (function_exists('is_front_page') && is_front_page()) {
        $file = ABSPATH . 'home/index.html';
        if (is_readable($file)) {
            header('Content-Type: text/html; charset=UTF-8');
            readfile($file);
            exit;
        }
    }
    return $template;
});
