<?php
$labels = wtp_langs();
$lang = wtp_detect_lang();
$ordered = array_merge([$lang], array_diff(array_keys($labels), [$lang]));
?>
<div class="container">
  <nav class="wtp-langbar">
    <?php foreach($ordered as $code): ?>
      <a href="<?php echo esc_url(add_query_arg('wtp_lang',$code)); ?>" class="<?php echo $code===$lang?'active':''; ?>">
        <span><?php echo esc_html($labels[$code]); ?></span>
      </a>
    <?php endforeach; ?>
  </nav>
</div>