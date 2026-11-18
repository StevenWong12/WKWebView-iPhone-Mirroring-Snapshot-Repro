# WKWebView `takeSnapshot` + iPhone Mirroring repro

This standalone iOS app reproduces a `WKWebView.takeSnapshot` failure seen while Apple iPhone Mirroring is active:

- completion returns with `error == nil`;
- the `UIImage` has the expected dimensions;
- PNG encoding succeeds;
- every output pixel has alpha `0`.

The app loads a local red/purple HTML fixture in a `WKWebView` attached to the view controller and positioned immediately outside the visible bounds, then captures it with `WKSnapshotConfiguration`.

## Run

1. Open `WKWebViewMirroringSnapshotRepro.xcodeproj` in Xcode.
2. Select your development team if Xcode asks for signing.
3. Run on a physical iPhone.
4. Start Apple's **iPhone Mirroring** app on the Mac. The physical iPhone will be locked as part of normal Mirroring behavior.
5. Tap **Capture Snapshot** in the mirrored app.

Expected normal result:

```text
fully transparent: NO — normal image
```

Observed failure:

```text
completion error: nil
image size: 320×240 pt
PNG bytes: <non-zero>
fully transparent: YES — BUG REPRODUCED
```

Use **Share PNG** to export the returned image.

## Control

Stop iPhone Mirroring, unlock the same iPhone, relaunch the app directly on the phone, and capture again. The same local HTML should produce a visible gradient image.

## Environment where originally observed

- iPhone17,3
- iOS 26.5 (23F77)
- Xcode 26.4 (17E192)

Related but not identical WebKit issue: [WebKit bug 314422](https://bugs.webkit.org/show_bug.cgi?id=314422), `rdar://169663416`.

## Regenerate the project

The generated `.xcodeproj` is committed in this folder. If needed, regenerate it with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
```
