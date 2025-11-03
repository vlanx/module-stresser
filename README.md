# Module Stresser

Various simple single-purpose containers to stress target a module.

## Worker Host prep (once)

Make your test dirs group-owned by the **same numeric GID** and inheriting group perms:
```bash
# Use the same GID you bake into the image (20001 here) 
sudo groupadd -g 20001 stresscontainers   # ok if it already exists 
sudo mkdir -p /var/lib/module-stresser/
sudo chgrp -R 20001 /var/lib/module-stresser/
sudo chmod 2775 /var/lib/module-stresser/
```

Dont forget to create this `stresscontainers` group so that every container shares it and has the same permissions.

For the creation of a random junk data big file for the `io` containers:

```bash
openssl enc -aes-256-ctr -pass pass:seed -nosalt \
 </dev/zero | dd of=/var/lib/module-stresser/fio_rand.dat bs=4M oflag=direct status=progress
```

Check the first 64 bytes of this newly created file:

```bash
xxd -l 64 fio_rand.dat
```
