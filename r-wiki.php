<?php
define('URL', 'http://localhost/redmine/projects/test/wiki');
define('KEY', '2a32c7e81df50e8e36e9d4ab72440c2477b7be4b');

$page = $_GET['p'];

$index = page_index();

$html = wiki_html($page, $index);

print_html($html);

exit;


function page_index() {
    $json = file_get_contents(URL . "/index.json?key=" . KEY);

    $var = json_decode($json);

    foreach ($var->wiki_pages as $p) {
        $index[] = $p->title;
    }

    return $index;
}

function wiki_html($page, $index) {
    if (in_array($page, $index)) {
        $url = URL . "/$page.html?key=" . KEY;
    }
    else {
        $url = URL . ".html?key=" . KEY;
    }

    $html = file_get_contents($url);

    foreach ($index as $i) {
        $html = str_replace("href=\"$i.html\"", "href=\"?p=$i\"", $html);
    }

    return $html;
}

function print_html($html) {
    print $html;
}

?>
