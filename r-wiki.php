<?php
const URL = 'http://localhost';
const PREFIX = '/redmine';
const PROJ = 'test'; // Project identifier
const WIKI = 'Wiki'; // Wiki start page
const KEY = '2a32c7e81df50e8e36e9d4ab72440c2477b7be4b';

main();

exit;


function print_html($html) {
    // Modify HTML here.

    print $html;
}

function main() {
    $page = $_GET['p'];
    $file = $_GET['f'];

    if (isset($file)) {
        print_content($file);
    }
    else {
        $index = page_index();

        $html = wiki_html($page, $index);

        print_html($html);
    }
}

function url($path) {
    return URL . PREFIX . '/' . join('/', $path) . '?key=' . KEY;
}

function page_index() {
    $json = file_get_contents(url(array('projects', PROJ, 'wiki/index.json')));

    $var = json_decode($json);

    foreach ($var->wiki_pages as $p) {
        $index[] = $p->title;
    }

    return $index;
}

function wiki_html($page, $index) {
    if (!in_array($page, $index)) $page = WIKI;

    $html = file_get_contents(url(array('projects', PROJ, "wiki/$page.html")));

    foreach ($index as $i) {
        $html = str_replace("href=\"$i.html\"", "href=\"?p=$i\"", $html);
    }

    $p = PREFIX . '/attachments/';

    $html = str_replace("src=\"$p", "src=\"?f=$p", $html);
    $html = str_replace("href=\"$p", "href=\"?f=$p", $html);

    return $html;
}

function print_content($file) {
    if (!is_valid_path($file)) exit;

    $content = file_get_contents(URL . "$file?key=" . KEY);

    $finfo = new finfo(FILEINFO_MIME_TYPE);

    header('Content-Type: ' . $finfo->buffer($content));
    header('Content-Disposition: attachment; filename*=UTF-8\'\''
    . rawurlencode(basename($file)));

    print $content;
}

function is_valid_path($path) {
    $p = PREFIX . '/attachments/';

    return preg_match("@^$p@", $path) && !preg_match("@/\.\.@", $path);
}

?>
