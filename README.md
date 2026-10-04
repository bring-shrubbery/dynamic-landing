# DynamicLanding

A Dynamic Island for macOS. A floating island pinned to the top edge of a screen — flush with the
notch where there is one, a rounded pill hanging from the top edge where there is not — with
three states: hidden, compact (a leading and a trailing slot around the notch, like iOS Live
Activities) and expanded (any SwiftUI content). Every animation grows down from the top edge and
widens about the screen's centre; nothing ever inflates from the island's middle.

```swift
import DynamicLanding

let island = DynamicLanding(configuration: .init(style: .automatic))
await island.show(compactLeading: { Image(systemName: "waveform") }, trailing: { Text("0:12") })
await island.show(expanded: { ListeningCard() })   // morphs in place
await island.hide()
island.onTap = { … }
```

macOS 14+, no dependencies, MIT. Used by [JustScribe](https://justscribe.quassum.com).

`swift run DynamicLandingDemo` shows a menu-bar demo with every state and style.
