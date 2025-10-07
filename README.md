# So You Want to Migrate...

If you have an account on a Bluesky mushroom PDS (`<mushroom>.*.bsky.network`) and want to migrate to another PDS (e.g., your own), this can currently be a daunting task. As of this writing, there are a few web-based migration tools available, but even with those you might end up in a situation where you have to resort to a manual migration process.

Here is a writeup of my experience moving my account to my own PDS. At that point, it was already quite full. Here are some numbers for illustration:
- ~10k posts
- ~800 blobs, some of them short videos
- A bit under 1 GB in total size

This led to some problems while trying to migrate with the recommended automatic migration function in the [goat](https://github.com/bluesky-social/goat) command-line tool. For posterity, I'll describe what I did, the problems I encountered, and how to work around them with explanations of what is happening.

---

First here are some useful links:

Web-based migration tools:
- [ATP Airport](https://atpairport.com/) - "Your terminal for seamless AT Protocol PDS migration and backup" by [Roscoe Rubin-Rottenberg](https://bsky.app/profile/knotbin.com)
- [PDS Moover](https://pdsmoover.com/) - Cow-themed migration tool by [Bailey Townsend](https://bsky.app/profile/baileytownsend.dev)
- [Tektite](https://tektite.cc/) - Tektite Migration Service by [Blacksky](https://bsky.app/profile/tektite.cc)

General documentation:
- [PDS Self-hosting](https://atproto.com/guides/self-hosting) - Official PDS self-host instructions
- [GitHub PDS](https://github.com/bluesky-social/pds) - Official PDS reference implementation (Docker) with installation instructions
- [Migration instructions](https://whtwnd.com/did:plc:44ybard66vv44zksje25o7dz/3l5ii332pf32u) by [Bryan Newbold](https://bsky.app/profile/bnewbold.net)
- [Adding recovery keys guide](https://whtwnd.com/bnewbold.net/3lj7jmt2ct72r) also by [Bryan Newbold](https://bsky.app/profile/bnewbold.net)
- [pdsls.dev](https://pdsls.dev) - Super handy tool to inspect basically everything in atproto by [juliet](https://bsky.app/profile/juli.ee)
	- For starters, just enter your handle
	- Feel free to click around; you cannot break anything without logging in first
- [Handle Debugger](https://bsky-debug.app/handle) - Check if your handle is valid

Optional links:
- [GitHub PDS source](https://github.com/bluesky-social/atproto/tree/main/packages/pds) - TypeScript source code for the PDS reference implementation
	- [Environment variables](https://github.com/bluesky-social/atproto/blob/main/packages/pds/src/config/env.ts) - All environment variables available for customization
- [GitHub atproto scraper](https://github.com/mary-ext/atproto-scraping) - Scraped list of all known PDS, including self-hosted
- [PDS directory](https://blue.mackuba.eu/directory/pdses) - Website listing known PDS instances with user counts
- [atproto browser](https://atproto-browser.vercel.app/) - Bare-bones atproto browser
- [atp tools](https://atp.tools/) - Another useful atproto browser/tools implementation

---

Now let's start. When I decided to migrate my account, I first looked at its current state with `pdsls.dev`:

```
ID
	did:plc:3zxgigfubnv4f47ftmqdsbal

Identities
    at://fry69.dev

Services
    #atproto_pds
    https://cordyceps.us-west.host.bsky.network

Verification methods
    #atprotoz Q3shgqQdc1Rr2A3dTJTAPF2Mu2Qe6BhSCyPFC4Uk5WNPkUsr
```

- `ID` - Points to the [DID](https://web.plc.directory/spec/v0.1/did-plc) for my account. This ID is fixed and must never change; all content (and followers) point to this ID
	- The DID points to a DID document that can be retrieved via [web.plc.directory](https://web.plc.directory/resolve)
	- The DID document contains information about where the account is hosted and which keys are valid (more about that later)
- `Identities` - The first entry from the `alsoKnownAs` field of the DID document
	- Note the absence of `https://bsky.social` in this field; an account is always independent of Bluesky PBC
- `Services` - Points to the PDS instance that hosts the account
- `Verification methods` - Records for this account must be signed with this method (public key) to be valid
	- Invalid records might be ignored/discarded by the network

---

The next step is installing the `goat` command-line tool. This requires a working Go environment. On my macOS laptop, I used these steps:

Assuming [Homebrew](https://brew.sh) is installed, this installs the Go compiler/environment:
```shell
brew install go
```
This fetches, compiles, and installs the `goat` tool:
```shell
go install github.com/bluesky-social/goat@latest
```
This adds the path where compiled Go binaries are stored to the system lookup path:
```shell
export PATH=$PATH:$HOME/go/bin
```

---

Now we can get some information about the account. Before I started the migration process, I decided to add a recovery key to my account/DID document, just to be safe (and also to get a feel for how this works). See the [guide](https://whtwnd.com/bnewbold.net/3lj7jmt2ct72r) already mentioned above.

> [!NOTE]
> **Why are recovery keys important?**
>
> When you create an account, the PDS holds keys for signing your records. This means a rogue PDS operator could overtake your account, or more mundane things like the PDS losing all data including your signing keys could happen. In this case, a recovery key gives you at least control back over your identity (including your followers). In such a catastrophic scenario, you can restore a backup of your account on a different PDS and initiate a PLC operation to point it at that new PDS with such a recovery key.

First, I have to log in to my account:
```shell
goat account login -u fry69.dev -p '[old_pw]'
```
> [!WARNING]
> Once logged in, destructive operations with `goat` are possible, like deleting records.
> PLC operations (changing the DID document) require a separate token via email.

This command gives an overview of the status of the account, including whether it is active and how many records/blobs it references:
```shell
$ goat account status
DID: did:plc:3zxgigfubnv4f47ftmqdsbal
Host: https://cordyceps.us-west.host.bsky.network
{
  "activated": true,
  "expectedBlobs": 1279,
  "importedBlobs": 1281,
  "indexedRecords": 81070,
  "privateStateValues": 0,
  "repoBlocks": 102665,
  "repoCommit": "bafyreihie34syw5ripq6m2ynxhvnwqrwztw6drltp42dnrasini2rjupyu",
  "repoRev": "3lnuu62camb26",
  "validDid": true
}
```

This command returns the current DID document for the account:
```shell
$ goat account plc current
trying to refresh auth from password...
{
  "did": "did:plc:3zxgigfubnv4f47ftmqdsbal",
  "verificationMethods": {
    "atproto": "did:key:zQ3shgqQdc1Rr2A3dTJTAPF2Mu2Qe6BhSCyPFC4Uk5WNPkUsr"
  },
  "rotationKeys": [
    "did:key:zQ3shhCGUqDKjStzuDxPkTxN6ujddP4RkEKJJouJGRRkaLGbg",
    "did:key:zQ3shpKnbdPx3g3CmPf5cRVTPe1HtSwVn5ish3wSnDPQCbLJK"
  ],
  "alsoKnownAs": [
    "at://fry69.dev"
  ],
  "services": {
    "atproto_pds": {
      "type": "AtprotoPersonalDataServer",
      "endpoint": "https://cordyceps.us-west.host.bsky.network"
    }
  }
}
```

Here is the workflow for adding a recovery key to the DID document:

Save the current DID document to compare later:
```
$ goat account plc current > plc-current.json
```
Generate a recovery key and (optionally) save it in a file:
```
$ goat key generate > key.txt
$ cat key.txt
Key Type: P-256 / secp256r1 / ES256 private key
Secret Key (Multibase Syntax): save this securely (eg, add to password manager)
	[secret key]
Public Key (DID Key Syntax): share or publish this (e.g., in DID document)
	did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY
```
> [!WARNING]
> Keep the secret key safe. Whoever has control of this key can take over your account.

Now I tried to add the key to my DID document, but the token I used was already expired (tokens may have less than an hour lifetime):
```
$ goat account plc add-rotation-key --token [via mail] did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY
400: ExpiredToken: Token is expired
```
This command requests a fresh token:
```
$ goat account plc request-token
Success; check email for token.
```
Now the command works:
```
$ goat account plc add-rotation-key --token [via mail] did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY
Success
```
Get the current, changed DID document and compare it to the old one to make sure the recovery key is in place and nothing else changed:
```
$ goat account plc current > plc-current-20250429.json
$ diff -u plc-current.json plc-current-20250429.json
--- plc-current.json	2025-04-29 07:56:56
+++ plc-current-20250429.json	2025-04-29 08:01:12
@@ -5,7 +5,8 @@
   },
   "rotationKeys": [
     "did:key:zQ3shhCGUqDKjStzuDxPkTxN6ujddP4RkEKJJouJGRRkaLGbg",
-    "did:key:zQ3shpKnbdPx3g3CmPf5cRVTPe1HtSwVn5ish3wSnDPQCbLJK"
+    "did:key:zQ3shpKnbdPx3g3CmPf5cRVTPe1HtSwVn5ish3wSnDPQCbLJK",
+    "did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY"
   ],
   "alsoKnownAs": [
     "at://fry69.dev"
```

---

That's it. The next step is the migration process:

If not already logged into the mushroom account:
```shell
$ goat account login -u fry69.dev -p '[old_pw]'
```
First, I tried the automated `goat account migrate` approach. For this, I wrote a little script:
```shell
#!/usr/bin/env bash

NEWPDSHOST="https://altq.net"
NEWHANDLE="fry69.altq.net" # not tested if existing handled @fry69.dev can get used
NEWPASSWORD="[new_pw]"
NEWEMAIL="fry-altq@fry69.dev" # not tested if old email address can get used

NEWPLCTOKEN="[from email]"
INVITECODE="altq-net-..."

goat account migrate \
    --pds-host $NEWPDSHOST \
    --new-handle $NEWHANDLE \
    --new-password $NEWPASSWORD \
    --new-email $NEWEMAIL \
    --plc-token $NEWPLCTOKEN \
    --invite-code $INVITECODE
```
This did not work and stopped the migration process repeatedly at the same point:
```shell
$ ./migration.sh
2025/04/28 16:14:55 INFO new host serviceDID=did:web:altq.net url=https://altq.net
2025/04/28 16:14:55 INFO creating account on new host handle=fry69.altq.net host=https://altq.net
2025/04/28 16:14:57 INFO migrating repo
2025/04/28 16:15:35 WARN request failed subsystem=RobustHTTPClient error="Post \"https://altq.net/xrpc/com.atproto.repo.importRepo\": net/http: request canceled" method=POST url=https://altq.net/xrpc/com.atproto.repo.importRepo
error: failed importing repo: request failed: Post "https://altq.net/xrpc/com.atproto.repo.importRepo": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```
The migration guide says `goat` commands can be repeated/retried if something fails, but this does not work for the automatic migration process:
```shell
$ ./migration.sh
2025/04/28 16:43:57 INFO new host serviceDID=did:web:altq.net url=https://altq.net
2025/04/28 16:43:57 INFO creating account on new host handle=fry69.altq.net host=https://altq.net
error: failed creating new account: XRPC ERROR 400: AlreadyExists: Repo already exists
```
Even if I delete the stale inactive account and try the automation process again, I run into the same `timeout` problem as above.

> [!NOTE]
> **How do I delete a stale account?**
>
> In my case, I deleted the stale account directly on my PDS server with this command:
>```shell
>pdsadmin account delete did:plc:3zxgigfubnv4f47ftmqdsbal
>```
> The `did:plc` DID must be the real DID. This is safe since this is only a stale, inactive copy of my real account, which still resided on the mushroom PDS at this point.

So I have to use the manual migration process, which is a little more involved. First, make sure that any stale account is removed (see above). Also make sure you are logged into the mushroom account with `goat`.

Now let's have a look at my PDS:
```shell
$ goat pds describe https://altq.net
{
  "availableUserDomains": [
    ".altq.net"
  ],
  "contact": {},
  "did": "did:web:altq.net",
  "inviteCodeRequired": true,
  "links": {}
}
```
Compare this to the official Bluesky mushroom PDS:
```shell
$ goat pds describe https://bsky.social
{
  "availableUserDomains": [
    ".bsky.social"
  ],
  "did": "did:web:bsky.social",
  "inviteCodeRequired": false,
  "links": {
    "privacyPolicy": "https://blueskyweb.xyz/support/privacy-policy",
    "termsOfService": "https://blueskyweb.xyz/support/tos"
  },
  "phoneVerificationRequired": true
}
```
Looks good. Now let's start exporting the data from the mushroom PDS, starting with the repository. It contains all records (posts, likes, accounts you follow, and all other non-Bluesky records), but it does **not** contain blobs (binary large objects: images, short videos):
```shell
$ goat repo export fry69.dev
downloading from https://cordyceps.us-west.host.bsky.network to: fry69.dev.20250504094733.car
```
The CAR file this generated is about 30 MB in size for my ~10k posts and other records.
> [!NOTE]
> **What the heck is CAR?**
>
> The standard file format for storing data objects is Content Addressable aRchives (CAR). The standard repository export format for atproto repositories is [CAR v1](https://ipld.io/specs/transport/car/carv1/), which have file suffix `.car` and MIME type `application/vnd.ipld.car`. See [here](https://atproto.com/specs/repository#car-file-serialization) for more details.

Now it's time to download my ~800 blobs (~1 GB total size). This is a slow process—it took ~1 hour with a fast downlink. The limiting factor is the mushroom PDS. And of course, it failed in the middle of the process:
```shell
$ goat blob export fry69.dev
downloading blobs to: fry69.dev_blobs
fry69.dev_blobs/bafkreia2gocqxxxx7amdujd6ycqhwlomnsoqtfrekef4mbblfg6cll7kve	downloaded
[...]
2025/05/04 10:11:50 WARN request failed subsystem=RobustHTTPClient error="Get \"https://cordyceps.us-west.host.bsky.network/xrpc/com.atproto.sync.getBlob?cid=bafkreiet7zkowtbwaz7s3fdneuyrqbegv45uidbzvzre33su5j3xsq5w24&did=did%3Aplc%3A3zxgigfubnv4f47ftmqdsbal\": net/http: request canceled" method=GET url="https://cordyceps.us-west.host.bsky.network/xrpc/com.atproto.sync.getBlob?cid=bafkreiet7zkowtbwaz7s3fdneuyrqbegv45uidbzvzre33su5j3xsq5w24&did=did%3Aplc%3A3zxgigfubnv4f47ftmqdsbal"
error: request failed: Get "https://cordyceps.us-west.host.bsky.network/xrpc/com.atproto.sync.getBlob?cid=bafkreiet7zkowtbwaz7s3fdneuyrqbegv45uidbzvzre33su5j3xsq5w24&did=did%3Aplc%3A3zxgigfubnv4f47ftmqdsbal": GET https://cordyceps.us-west.host.bsky.network/xrpc/com.atproto.sync.getBlob?cid=bafkreiet7zkowtbwaz7s3fdneuyrqbegv45uidbzvzre33su5j3xsq5w24&did=did%3Aplc%3A3zxgigfubnv4f47ftmqdsbal giving up after 1 attempt(s): context deadline exceeded (Client.Timeout exceeded while awaiting headers)

```
Thankfully, this command is repeatable and will skip already-downloaded blobs found on disk. It proceeded to the end on the second attempt:
```shell
$ goat blob export fry69.dev
downloading blobs to: fry69.dev_blobs
fry69.dev_blobs/bafkreia2gocqxxxx7amdujd6ycqhwlomnsoqtfrekef4mbblfg6cll7kve	exists
[...]
```

With the repository and the blobs safe on the local disk, only the proprietary preferences for the Bluesky AppView are missing. Compared to the other parts, this is a tiny object you can view with, e.g., [jq](https://jqlang.org/). This command downloads the preferences:
```shell
$ goat bsky prefs export > prefs.json
```
Just to be sure my account repository did not get modified in the process, I requested another export and compared the second one to the first one. They were identical (no surprise):
```
$ goat repo export fry69.dev
downloading from https://cordyceps.us-west.host.bsky.network to: fry69.dev.20250504103731.car
$ cmp fry69.dev.20250504094733.car fry69.dev.20250504103731.car # [no output -> identical]
```

The next step is to create a fresh (deactivated) account on my PDS. The AT Protocol requires requesting a service token for this. This can be requested and stored in an environment variable (it's a rather long token) with this command (requires login, but **not** on the new PDS—mushroom PDS login is fine):
```shell
$ SERVICEAUTH=$(goat account service-auth --lxm com.atproto.server.createAccount --duration-sec 3600 --aud "did:web:altq.net")
```
This command creates the new account:
```shell
$ goat account create --service-auth $SERVICEAUTH --pds-host "https://altq.net" --existing-did "did:plc:3zxgigfubnv4f47ftmqdsbal" --handle fry69.altq.net --password "[new_pw]" --email "fry-altq@fry69.dev" --invite-code altq-net-[...]
Success!
DID: did:plc:3zxgigfubnv4f47ftmqdsbal
Handle: fry69.altq.net
```
> [!NOTE]
> It may be possible to reuse the existing handle (`fry69.dev`) and email address. I used different ones because I was unsure. I'd love feedback on this.

With this fresh account in place, it's time to log in to the new PDS and import the data:
> [!WARNING]
> Login change

```
$ goat account login --pds-host "https://altq.net" -u "did:plc:3zxgigfubnv4f47ftmqdsbal" -p "[new_pw]"
```

The first step is to upload the repository with the posts, likes, etc. Of course, this produced an error:
```shell
$ goat repo import ./fry69.dev.20250504103731.car
2025/05/04 10:58:18 WARN request failed subsystem=RobustHTTPClient error="Post \"https://altq.net/xrpc/com.atproto.repo.importRepo\": net/http: request canceled" method=POST url=https://altq.net/xrpc/com.atproto.repo.importRepo
error: failed to import repo: request failed: Post "https://altq.net/xrpc/com.atproto.repo.importRepo": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```
Panic! What happened? Let's check. This command shows the status of the new (inactive) account on the new PDS:
```shell
$ goat account status
DID: did:plc:3zxgigfubnv4f47ftmqdsbal
Host: https://altq.net
{
  "activated": false,
  "expectedBlobs": 1329,
  "importedBlobs": 0,
  "indexedRecords": 84230,
  "privateStateValues": 0,
  "repoBlocks": 106702,
  "repoCommit": "bafyreiegjvpriioc4dqhrmoq2txz7jkpovtwnxunu2x6pbwirphmldydfi",
  "repoRev": "3lodie5dgnc25",
  "validDid": false
}
```
Hmm, looks fine to me. To be safe, I re-ran the import command. This time there was no error, but the account repository also did not change in a noticeable way:
```shell
$ goat repo import ./fry69.dev.20250504103731.car
$ goat account status
DID: did:plc:3zxgigfubnv4f47ftmqdsbal
Host: https://altq.net
{
  "activated": false,
  "expectedBlobs": 1329,
  "importedBlobs": 0,
  "indexedRecords": 84230,
  "privateStateValues": 0,
  "repoBlocks": 106702,
  "repoCommit": "bafyreiegjvpriioc4dqhrmoq2txz7jkpovtwnxunu2x6pbwirphmldydfi",
  "repoRev": "3lodimlm5gk25",
  "validDid": false
}
```
With the repository in place, it's possible to ask the PDS which blobs are missing with this command (huge output):
```shell
$ goat account missing-blobs
bafkreia2gocqxxxx7amdujd6ycqhwlomnsoqtfrekef4mbblfg6cll7kve	at://did:plc:3zxgigfubnv4f47ftmqdsbal/app.bsky.feed.post/3lmevjd26m22x
[...]
```
To upload the missing blobs from the local disk to the PDS, I wrote this command. This checks if it does what it should (assuming the blobs are located in the folder `fry69.dev_blobs`):
```shell
$ find fry69.dev_blobs -type f -exec echo goat blob upload {} \;
goat blob upload fry69.dev_blobs/bafkreifjp4eprt6l43xlxzf7dj2ofv6apnb6loludnujaamv3sth7a5thq
[...]
```
Now run this command without the `echo`. Double-check the output after running this—it will not automatically retry or list errors separately:
```shell
$ find fry69.dev_blobs -type f -exec goat blob upload {} \;
{
  "$type": "blob",
  "ref": {
    "$link": "bafkreifjp4eprt6l43xlxzf7dj2ofv6apnb6loludnujaamv3sth7a5thq"
  },
  "mimeType": "image/jpeg",
  "size": 994679
}
[...]
```
Of course, there was an error in the middle of the upload:
```shell
2025/05/04 11:12:14 WARN request failed subsystem=RobustHTTPClient error="Post \"https://altq.net/xrpc/com.atproto.repo.uploadBlob\": net/http: request canceled" method=POST url=https://altq.net/xrpc/com.atproto.repo.uploadBlob
error: request failed: Post "https://altq.net/xrpc/com.atproto.repo.uploadBlob": POST https://altq.net/xrpc/com.atproto.repo.uploadBlob giving up after 3 attempt(s): context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```
Retrying this command did not help:
```shell
$ goat blob upload fry69.dev_blobs/bafkreifh3ix2tgaqt6hkjp222kreejcpgypebanr5tj6aaqnpaw53upwda
2025/05/04 11:21:59 WARN request failed subsystem=RobustHTTPClient error="Post \"https://altq.net/xrpc/com.atproto.repo.uploadBlob\": net/http: request canceled" method=POST url=https://altq.net/xrpc/com.atproto.repo.uploadBlob
error: request failed: Post "https://altq.net/xrpc/com.atproto.repo.uploadBlob": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```
> [!NOTE]
> **Hitting the PDS Upload Limit**
>
> This led to a side quest where I found out that my PDS was still set to the original 50 MB upload limit, but the mushroom PDS raised this to 100 MB and 3-minute length for videos a while after I set up the PDS. The solution for this problem is changing the following line in the `/pds/pds.env` file on the PDS server:
>```shell
>PDS_BLOB_UPLOAD_LIMIT=104857600
>```
> Don't forget to restart the PDS afterward (reboot or `systemctl restart pds`).

With that fix in place, the upload of the missing blob worked fine:
```shell
$ goat blob upload fry69.dev_blobs/bafkreifh3ix2tgaqt6hkjp222kreejcpgypebanr5tj6aaqnpaw53upwda
{
  "$type": "blob",
  "ref": {
    "$link": "bafkreifh3ix2tgaqt6hkjp222kreejcpgypebanr5tj6aaqnpaw53upwda"
  },
  "mimeType": "video/mp4",
  "size": 70418954
}
```
Everything looks fine now:
```shell
$ goat account status
DID: did:plc:3zxgigfubnv4f47ftmqdsbal
Host: https://altq.net
{
  "activated": false,
  "expectedBlobs": 1329,
  "importedBlobs": 1329,
  "indexedRecords": 84230,
  "privateStateValues": 0,
  "repoBlocks": 106702,
  "repoCommit": "bafyreiegjvpriioc4dqhrmoq2txz7jkpovtwnxunu2x6pbwirphmldydfi",
  "repoRev": "3lodimlm5gk25",
  "validDid": false
}
$ goat account missing-blobs # no output means no blobs are missing, yay!
```

---

The final step is to change the DID document for the account to point to the new PDS (which also has a different verification method/signing key). This may require a bit of logging in and out between the two accounts if things don't work out. First, check the current state of the DID document for the new account on the PDS (note the `recommended`—it is not yet uploaded to the DID registry):

```shell
$ goat account plc recommended > plc_new.json
$ cat plc_new.json
{
  "alsoKnownAs": [
    "at://fry69.altq.net"
  ],
  "verificationMethods": {
    "atproto": "did:key:zQ3shSuymtEUXUsN1pyZACZ6WGk3Tktxe4s1JyL4CSWLRWaZa"
  },
  "rotationKeys": [
    "did:key:zQ3shcFsHHoawNae6vDx4HNamQVZEVrcQ1Uc2gwi5f9qxR6Xi"
  ],
  "services": {
    "atproto_pds": {
      "type": "AtprotoPersonalDataServer",
      "endpoint": "https://altq.net"
    }
  }
}
```
Compare this to the official DID document at this point:
```shell
$ goat account plc current
{
  "did": "did:plc:3zxgigfubnv4f47ftmqdsbal",
  "verificationMethods": {
    "atproto": "did:key:zQ3shgqQdc1Rr2A3dTJTAPF2Mu2Qe6BhSCyPFC4Uk5WNPkUsr"
  },
  "rotationKeys": [
    "did:key:zQ3shhCGUqDKjStzuDxPkTxN6ujddP4RkEKJJouJGRRkaLGbg",
    "did:key:zQ3shpKnbdPx3g3CmPf5cRVTPe1HtSwVn5ish3wSnDPQCbLJK",
    "did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY"
  ],
  "alsoKnownAs": [
    "at://fry69.dev"
  ],
  "services": {
    "atproto_pds": {
      "type": "AtprotoPersonalDataServer",
      "endpoint": "https://cordyceps.us-west.host.bsky.network"
    }
  }
}
```
Now edit the `plc_new.json` with your favorite editor and add, e.g., the additional recovery key to the proposed new DID document (note that I got carried away and changed the `alsoKnownAs` field—do not do this):
```shell
$ cat plc_new.json
{
  "alsoKnownAs": [
    "at://fry69.dev"
  ],
  "verificationMethods": {
    "atproto": "did:key:zQ3shSuymtEUXUsN1pyZACZ6WGk3Tktxe4s1JyL4CSWLRWaZa"
  },
  "rotationKeys": [
    "did:key:zQ3shcFsHHoawNae6vDx4HNamQVZEVrcQ1Uc2gwi5f9qxR6Xi",
    "did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY"
  ],
  "services": {
    "atproto_pds": {
      "type": "AtprotoPersonalDataServer",
      "endpoint": "https://altq.net"
    }
  }
}
```
Now it's necessary to log in to the mushroom account, which has a pointer to the valid DID document, request a token from the PLC (you'll receive it via email), and sign the new DID document:
```shell
$ goat account login -u fry69.dev -p '[old_pw]'
$ goat account plc request-token
Success; check email for token.
$ goat account plc sign --token [token] ./plc_new.json > plc_new_signed.json
```
The signed DID document should look like this:
```shell
$ cat plc_new_signed.json
{
  "prev": "bafyreic6drt4uv43zrsd54lexmwwvg72dnlswjyqizstjttkuovlyqq4n4",
  "type": "plc_operation",
  "services": {
    "atproto_pds": {
      "type": "AtprotoPersonalDataServer",
      "endpoint": "https://altq.net"
    }
  },
  "alsoKnownAs": [
    "at://fry69.dev"
  ],
  "rotationKeys": [
    "did:key:zQ3shcFsHHoawNae6vDx4HNamQVZEVrcQ1Uc2gwi5f9qxR6Xi",
    "did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY"
  ],
  "verificationMethods": {
    "atproto": "did:key:zQ3shSuymtEUXUsN1pyZACZ6WGk3Tktxe4s1JyL4CSWLRWaZa"
  },
  "sig": "zPhjYO_DMby4Ky-mHhIjLTAv4hrhiGQtofn0QoLMjRtj_s64-dZPVZ8kQSe1WOgzScwHVa5jL6dy-NzIIjzaww"
}
```
Now log in to the new PDS before submitting (otherwise you'll get an error about rotation keys):
```shell
$ goat account login --pds-host "https://altq.net" -u "did:plc:3zxgigfubnv4f47ftmqdsbal" -p "[new_pw]"
```
Now let's submit the new DID document. Of course, it failed because I made a mistake:
> [!WARNING]
> PLC Operation / DID Document Update Ahead
```shell
$ goat account plc submit ./plc_new_signed.json
error: failed submitting PLC op via PDS: XRPC ERROR 400: InvalidRequest: Incorrect handle in alsoKnownAs
```
And no, just changing the `alsoKnownAs` field to the correct value doesn't work, as this invalidates the signature (as expected, but good to see this working as intended):
```shell
$ goat account plc submit ./plc_new_signed.json
error: failed submitting PLC op via PDS: XRPC ERROR 400: InvalidRequest: Invalid signature on op: {"type":"plc_operation","rotationKeys":["did:key:zQ3shcFsHHoawNae6vDx4HNamQVZEVrcQ1Uc2gwi5f9qxR6Xi","did:key:zDnaenr1u5hpX7AznPRZ2kgTzpoFdEYRiPrZMyzmXFGFgGkTY"],"verificationMethods":{"atproto":"did:key:zQ3shSuymtEUXUsN1pyZACZ6WGk3Tktxe4s1JyL4CSWLRWaZa"},"alsoKnownAs":["at://fry69.altq.net"],"services":{"atproto_pds":{"type":"AtprotoPersonalDataServer","endpoint":"https://altq.net"}},"prev":
```
To fix this, I had to sign the fixed `plc_new.json` again, with a new requested token from the PLC. This finally worked:
```shell
$ goat account plc submit ./plc_new_signed.json
$ goat account status
DID: did:plc:3zxgigfubnv4f47ftmqdsbal
Host: https://altq.net
{
  "activated": false,
  "expectedBlobs": 1329,
  "importedBlobs": 1329,
  "indexedRecords": 84230,
  "privateStateValues": 0,
  "repoBlocks": 106702,
  "repoCommit": "bafyreiegjvpriioc4dqhrmoq2txz7jkpovtwnxunu2x6pbwirphmldydfi",
  "repoRev": "3lodimlm5gk25",
  "validDid": true
}
```
🎉 `validDid: true` yay! 🎉

But my handle was now `@fry69.altq.net`. This was easily solvable by using the change handle feature in the official web client to set it back to `@fry69.dev`.

> [!NOTE]
> **What happens with the old account on the mushroom PDS?**
>
> I'm glad you asked. This is currently unclear. If you log in to your mushroom account with the official https://bsky.app/ web client (this is still possible—choose Bluesky Social as your host during login), you will notice that the timeline will not load. But you can get to the settings page and from there to the account and try to delete your account. This will not work, probably because the deletion process will try to delete your chats, bookmarks, and mutes (which you certainly want to keep), or for some other reason.

You can deactivate your mushroom account in the web client or with `goat` like this:
```shell
$ goat account login -u fry69.dev -p '[old_pw]' --pds-host "https://cordyceps.us-west.host.bsky.network"
$ goat account deactivate
```

If you read until here and spotted a problem, typo, or want to leave a different comment/suggestion: Please file an [issue](https://github.com/fry69/bluesky-migration-guide/issues/new) in the GitHub [repository](https://github.com/fry69/bluesky-migration-guide) for this guide, or [ping me](https://bsky.app/profile/fry69.dev) on Bluesky.

Thank you and happy, less troublesome, migration!
