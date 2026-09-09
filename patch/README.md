# Patch

`DBZ-english-v13.ips` is the current English patch (experimental; may still have bugs).

Apply it with Lunar IPS, Floating IPS or `perl tools/applyips.pl rom/DB.gb patch/DBZ-english-v13.ips out.gb`
to a clean dump of the Japanese ROM (512 KB, SHA-1 `1f7a08d2e51e90d770d9dbf4092166b2bfa5697e`).
The patched ROM is 1 MB (MBC5): each story scene lives in its own ROM bank. Saves from the Japanese ROM keep working.
