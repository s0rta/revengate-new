Release Procedure
=================

When the code gets to the point where it seems ready to publish, the following steps should be undertaken.

* bump version string and version code in `src/constants.gd`
* `git tag vX.Y.Z`
* `invoke build-android`
* try the new package: `adb install bin/revengate-x.y.z.apk`
* `git push --tag; git push --tag public`
* update rengate.org (~/proj/rev-org/docs/download.md)
* upload the new aab to Google Play (internal testing, then promote to the other tracks)
* update the [Rogue Basin front page](https://roguebasin.com/index.php/Main_Page) and the [Revengate Page](https://roguebasin.com/index.php/Revengate)

F-Droid monitors for new tags and should build a new package automatically.
