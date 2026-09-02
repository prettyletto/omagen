# Product README authoring guide

`README.md` in this directory is the canonical source for the stable product
README. Write it for users, not contributors. The root README on `nightly` and
`dev` remains the developer guide until the controlled release promotion.

Keep the product README focused on the user journey:

- the problem Omagen solves and the visual result;
- screenshots, demos, and curated examples;
- stable installation, first use, and normal usage;
- upgrade, recovery, rollback, and removal;
- capabilities, trust boundaries, ownership, and limitations; and
- links to the complete product documentation under this directory.

Use `<!-- omagen-product-source-only:start -->` and
`<!-- omagen-product-source-only:end -->` around maintainer instructions that
are useful while authoring but must not appear in the stable root README.

The promotion workflow validates links from this directory, rewrites relative
links for the root README projection, records the exact `dev` source SHA, and
opens a reviewed pull request into `main`. Do not manually edit the projected
root README on `dev` or `nightly`.
