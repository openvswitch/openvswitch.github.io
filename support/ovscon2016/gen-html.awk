{
    printf("  <tr>\n    <td>\n      <b>%s</b> (%s)\n    </td>\n    <td>\n      <a href=\"%s.pdf\">PDF</a>\n    </td>\n", $1, $2, $3);
    if ($4 != "") {
        printf("    <td>\n      <a href=\"%s\">Video</a>\n    </td>\n", $4);
    }
    printf("  </tr>\n");
}

