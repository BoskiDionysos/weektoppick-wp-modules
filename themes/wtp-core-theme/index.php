<?php
/** Minimal index required by WordPress */
get_header();
?>
<main id="primary" class="site-main">
  <div class="container">
    <?php
    if (have_posts()) {
      while (have_posts()) {
        the_post();
        the_title('<h1>', '</h1>');
        the_content();
      }
    } else {
      echo '<p>No content yet.</p>';
    }
    ?>
  </div>
</main>
<?php get_footer(); ?>
