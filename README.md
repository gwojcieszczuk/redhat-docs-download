# redhat-docs-download
Download PDF version of Official RedHat Documentation from CLI

```
Documents are downloaded to current/working directory.

./docsync.sh -h                             Show this help
./docsync.sh -l                             List all products
./docsync.sh -d red_hat_enterprise_linux -l List versions for <red_hat_enterprise_linux>
./docsync.sh -d all                         Download documentation for all products
./docsync.sh -d red_hat_enterprise_linux    Download documentation for <red_hat_enterprise_linux>  
./docsync.sh -d red_hat_enterprise_linux -v 9    Download documentation for <red_hat_enterprise_linux> version 9 
```


Still works: 2026-05-12

*Keep in mind that the script may break if Redhat restructures their documentation portal at some point.*
