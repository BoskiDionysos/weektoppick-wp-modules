<?php
$lang = wtp_detect_lang();
$dict = wtp_i18n($lang);
$top = $dict['charity.top_msg'] ?? 'We support charitable causes —';
$bottom = $dict['charity.bottom_msg'] ?? '10% of our commission goes to:';
$learn = $dict['charity.learn'] ?? 'Learn how we help';
?>
<div class="container">
  <div class="wtp-charity" role="complementary" aria-label="charity">
    <strong><?php echo esc_html($top); ?></strong>
    <div><a href="/charity/"><?php echo esc_html($learn); ?></a></div>
    <div style="margin-top:8px;">
      <?php echo esc_html($bottom); ?> <strong>GiveDirectly</strong>
    </div>
  </div>
</div>