# openvswitch.github.io

Website for Open vSwitch. This is written in Jekyll. We use:

- the templating engine, to format yaml data into html (for the navbar), to use
  jekyll variables (`page.url`, `site.url`, `page.title`)

- the layout mechanism. Each page includes only its specific content and
  declare its layout (which is a html file that contains the logo, the navbar,
  the footer...)

We do not use:

- blog specific mechanisms: we do not have blogs, we do not have posts.  We do
  not have a `_post/` directory.

## Development

You can develop using `docker-compose`:

    $ docker-compose up

You should see your site at http://localhost:4000/

Alternatively, install the Jekyll dependencies (2.x only, for now), then run:

    $ jekyll server -w

in the main site directory. This will be available at the
http://localhost:4000/

## Deployment

GitHub pages supports Jekyll without any further changes. To deploy locally,
run:

    $ jekyll build

in the main site directory. This will output to `_site/`, the contents of which
can be exported with any static HTTP server.

## Design

### Layouts

The skel (`_layouts/skel.html`) layout contains the header (logo+navbar) and
the footer. Only the home page uses this.

The page (`_layouts/page.html`) layout "inherits" from the skel layout and adds
a series of widgets (updates, recent releases, ...) and the title inside the
mainpage div. Almost every page uses this.

The pagenosidewidget (`_layouts/pagenosidewidget.html`) layout "inherits" from
the skel layout and adds only the title inside the mainpage div.

The CSS that we use is inspired by the wordpress output (but it's supposed to
be directly maintainable). It uses heavily fixed sized elements (i.e. we
explicitly specify the size in px).

Layouts rely on includes

### Includes

We use includes to split html in multiple files. For example the side widgets
are on `_include/side_widgets.html`.

### Navigation bar

- Style

  The navbar is only a nested series of `<ul><li>` elements (this is in line
  with current best practices).  The navbar display behavior (display/hide
  submenus) is implemented only in CSS, in a style tag inside header.html. It
  should support an unlimited number of nested submenus

- Content:

  Jekyll (at least the safe version used by github pages) does not support a
  way to generate a page list. Therefore we manually list the pages that we
  want to appear in the navbar (in order) in `_data/nav.yml`. The url attribute
  is relative to the parent page.  A bit of templating magic (recursively
  including `menulist.html`, with different `include.*` variables) allows us to
  generate the `<ul><li>` elements

The skel layout includes `_includes/header.html` which includes
`_includes/menulist.html`.

### Pages

Jekyll allows us to write page content in html or markdown. Most of the pages
are HTML now, since that is the output of the wordpress importer. Pages that
require advanced styling (e.g. the homepage) should be in html too.

Currently all the pages use a directory URL (e.g.
http://openvswitch.org/support/) The page is stored in a file called index.html
(or index.markdown)

Each page has a yaml preamble that contains the title, the layout that we want,
and some other information extracted by wordpress that it might be worth
keeping.

## TODO

- Refine style:

  Test with many browsers

- Navigation summary (under the navbar)

  A > B > C

- There are some TODO in the files. grep for them

- Remove useless info from the preamble? (author, ...)

## Open issues

1) Releases

   This repository currently does not host ovs releases as the oldwebsite did.

   Proposals:

   a) do not host them. Let github generate the files through tags

      + simple

      - Is github reliable? does the file change? Some user might expect it to
        have a consistent hash

   b) upload them to the website git repository

2) /cgi-bin/man

   There was a script on the old website that generated updated (from master)
   man pages (in PDF and HTML). There are some links to these pages somewhere
   on the website. Proposals:

   a) upload static version of the manpages

      - they do not get updated

3) /pipermail/

   `http://openvswitch.org/pipermail` is the mailman archive. If we use github
   hosting, openvswitch.org will be a CNAME for `openvswitch.github.io` (or
   something similar). Since we do not have control over
   `openvswitch.github.io` we cannot redirect `/pipermail/*` to something else.

4) google analytics

   include google analytics snippet
