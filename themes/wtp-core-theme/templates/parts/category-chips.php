<?php
$lang = wtp_detect_lang();
$slugs = wtp_parent_slugs();
?>
<div class="container">
  <div class="wtp-chips">
    <?php foreach($slugs as $slug): 
        $term = get_term_by('slug',$slug,'category');
        $name = wtp_display_name($slug,$term,$lang);
        $icon_path = get_stylesheet_directory().'/assets/icons/'.$slug.'.svg';
        $icon_url  = file_exists($icon_path) ? get_stylesheet_directory_uri().'/assets/icons/'.$slug.'.svg' : get_stylesheet_directory_uri().'/assets/icons/default.svg';
        $target = 'sub-'.$slug;
    ?>
      <a href="#" class="wtp-chip" data-wtp-toggle="<?php echo esc_attr($target) ?>">
        <img alt="" src="<?php echo esc_url($icon_url); ?>" width="18" height="18" loading="lazy"/>
        <span><?php echo esc_html($name); ?></span>
      </a>
    <?php endforeach; ?>
  </div>

  <?php foreach($slugs as $slug): 
        $term = get_term_by('slug',$slug,'category');
        if (!$term) continue;
        $children = get_terms(['taxonomy'=>'category','parent'=>$term->term_id,'hide_empty'=>false]);
        if (empty($children) || is_wp_error($children)) continue;
        // order by meta wtp_order (int) then name
        usort($children, function($a,$b){
            $oa = (int)get_term_meta($a->term_id,'wtp_order',true);
            $ob = (int)get_term_meta($b->term_id,'wtp_order',true);
            if ($oa === $ob) return strcasecmp($a->name,$b->name);
            return $oa <=> $ob;
        });
        $target = 'sub-'.$slug;
  ?>
    <div class="wtp-subchips" data-wtp-sub="<?php echo esc_attr($target) ?>">
      <?php foreach($children as $c): ?>
        <a href="<?php echo esc_url(get_term_link($c)); ?>" class="wtp-chip"><?php echo esc_html(wtp_display_name($c->slug,$c,$lang)); ?></a>
      <?php endforeach; ?>
    </div>
  <?php endforeach; ?>
</div>