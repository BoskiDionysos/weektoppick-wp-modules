<!doctype html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<header class="site-header">
  <div class="container">
    <a href="<?php echo esc_url(home_url('/')); ?>" class="site-title">
      <?php bloginfo('name'); ?>
    </a>
  </div>
</header>
