# Contributing

Small, focused pull requests are welcome. Explain what changed and how you
verified it. Keep the default review text `blocked` and the first-run dry-run
behavior intact unless the change explicitly addresses configuration.

Run the companion tests and firmware checks documented in their READMEs. For
enclosure changes, regenerate exported models and document the board revision,
switch, printer, material, and measured fit if physically tested.

Never use a real pull request to test review submission without its owner's
permission. Tests should inject fake browser/process/serial inputs. Do not
commit credentials, local build caches, or personal configuration.

Source code, documentation, and original enclosure design files in this
repository are licensed under MIT; external product names and linked vendor
materials belong to their respective owners.
