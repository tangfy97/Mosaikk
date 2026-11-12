# Security

Mosaikk reads pictures and writes collage files and images on your Mac, so problems that could lose, expose or corrupt files are taken seriously.

If you find a security issue, please email **hello@tang-spark.no** instead of opening a public issue. Include the steps to reproduce it and the version of Mosaikk and macOS. You will get a reply within a few days, and a fix will be released as soon as it is ready.

Mosaikk makes no network connections, so most reports will be about file handling: a crafted picture or `.mosaikk` file that crashes the app or uses too much memory, writing outside the place you chose, or reading files you did not add. Collage files are checked and repaired when opened (unknown values are clamped, missing pictures removed), and pictures are decoded at the size they are drawn.
